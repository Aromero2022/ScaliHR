-- ============================================================
-- Migration: ARCO Rights (Derechos ARCO)
-- Mexican data protection: Acceso, Rectificación, Cancelación, Oposición
-- ============================================================

-- ── ARCO request types & statuses ──────────────────────────────
DO $$ BEGIN
  CREATE TYPE arco_request_type AS ENUM ('acceso','rectificacion','cancelacion','oposicion');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE arco_request_status AS ENUM ('pending','in_progress','completed','rejected');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── arco_requests table ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS arco_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenants(id),
  requester_id  uuid NOT NULL REFERENCES users(id),
  subject_id    uuid NOT NULL REFERENCES users(id),
  request_type  arco_request_type NOT NULL,
  status        arco_request_status NOT NULL DEFAULT 'pending',
  description   text NOT NULL,
  resolution_notes text,
  export_hash   text,
  due_date      date NOT NULL,
  completed_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_arco_requests_tenant ON arco_requests(tenant_id);
CREATE INDEX IF NOT EXISTS idx_arco_requests_subject ON arco_requests(subject_id);
CREATE INDEX IF NOT EXISTS idx_arco_requests_status ON arco_requests(status);

-- ── RLS ────────────────────────────────────────────────────────
ALTER TABLE arco_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE arco_requests FORCE ROW LEVEL SECURITY;

CREATE POLICY arco_requests_select ON arco_requests
  FOR SELECT TO authenticated
  USING (tenant_id = (current_setting('app.current_tenant_id', true))::uuid);

CREATE POLICY arco_requests_insert ON arco_requests
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id = (current_setting('app.current_tenant_id', true))::uuid);

CREATE POLICY arco_requests_update ON arco_requests
  FOR UPDATE TO authenticated
  USING (tenant_id = (current_setting('app.current_tenant_id', true))::uuid);

-- No DELETE policy: soft-delete only paradigm

-- ── is_anonymized flag on users ────────────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_anonymized boolean NOT NULL DEFAULT false;

-- ── Compute due date: 20 business days from now ────────────────
CREATE OR REPLACE FUNCTION compute_arco_due_date(p_start date DEFAULT CURRENT_DATE)
RETURNS date
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  v_count int := 0;
  v_date  date := p_start;
BEGIN
  WHILE v_count < 20 LOOP
    v_date := v_date + 1;
    IF EXTRACT(dow FROM v_date) NOT IN (0, 6) THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;
  RETURN v_date;
END;
$$;

-- ── Anonymize user PII (cancelación) ───────────────────────────
-- Replaces PII with tokens, sets is_anonymized=true, soft-deletes.
-- The reidentification map is returned as JSONB so the caller can
-- store it server-side (never exposed to the client).
CREATE OR REPLACE FUNCTION anonymize_user(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_token text;
  v_map   jsonb := '{}'::jsonb;
  v_user  record;
  v_pi    record;
BEGIN
  SELECT * INTO v_user FROM users WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;

  v_token := 'ANON-' || substr(md5(p_user_id::text || now()::text), 1, 8);

  v_map := jsonb_build_object(
    'original_first_name', v_user.first_name,
    'original_last_name',  v_user.last_name,
    'original_email',      v_user.email,
    'token', v_token
  );

  UPDATE users SET
    first_name    = v_token,
    last_name     = 'ANONIMIZADO',
    email         = v_token || '@removed.local',
    is_anonymized = true,
    deleted_at    = now(),
    status        = 'TERMINATED',
    updated_at    = now()
  WHERE id = p_user_id;

  -- Anonymize all ec_personal_information records
  FOR v_pi IN SELECT id FROM ec_personal_information WHERE user_id = p_user_id LOOP
    UPDATE ec_personal_information SET
      first_name              = v_token,
      last_name               = 'ANONIMIZADO',
      middle_name             = NULL,
      phone                   = NULL,
      personal_email          = NULL,
      national_id             = NULL,
      tax_id                  = NULL,
      imss_number             = NULL,
      address_line1           = NULL,
      address_line2           = NULL,
      city                    = NULL,
      state                   = NULL,
      postal_code             = NULL,
      emergency_contact_name  = NULL,
      emergency_contact_phone = NULL
    WHERE id = v_pi.id;
  END LOOP;

  RETURN v_map;
END;
$$;

REVOKE ALL ON FUNCTION anonymize_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION anonymize_user(uuid) TO authenticated;

-- ── Export user data as JSONB (acceso) ─────────────────────────
CREATE OR REPLACE FUNCTION export_user_data(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  v_result jsonb := '{}'::jsonb;
  v_user   jsonb;
  v_jobs   jsonb;
  v_comp   jsonb;
  v_pi     jsonb;
BEGIN
  SELECT to_jsonb(u.*) INTO v_user
    FROM users u WHERE u.id = p_user_id;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(j.*) ORDER BY j.start_date DESC), '[]'::jsonb)
    INTO v_jobs
    FROM ec_job_information j WHERE j.user_id = p_user_id;

  SELECT coalesce(jsonb_agg(to_jsonb(c.*) ORDER BY c.start_date DESC), '[]'::jsonb)
    INTO v_comp
    FROM ec_compensation c WHERE c.user_id = p_user_id;

  SELECT coalesce(jsonb_agg(to_jsonb(p.*) ORDER BY p.start_date DESC), '[]'::jsonb)
    INTO v_pi
    FROM ec_personal_information p WHERE p.user_id = p_user_id;

  v_result := jsonb_build_object(
    'user',                 v_user,
    'job_information',      v_jobs,
    'compensation',         v_comp,
    'personal_information', v_pi,
    'exported_at',          now()::text
  );

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION export_user_data(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION export_user_data(uuid) TO authenticated;

-- ── Seed: no demo arco_requests needed ─────────────────────────
