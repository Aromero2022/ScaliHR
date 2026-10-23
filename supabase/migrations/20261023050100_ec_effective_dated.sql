-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Loop 4 — Step 2: Effective-Dated Records                          ║
-- ║  ec_job_information, ec_compensation, ec_personal_information      ║
-- ║  btree_gist + EXCLUDE constraints, insert_effective_record()       ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════
-- 1. EXTENSION: btree_gist for EXCLUDE constraints on daterange
-- ═══════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ═══════════════════════════════════════════════════════════════════
-- 2. EC_JOB_INFORMATION: per-employee job record with effective dates
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.ec_job_information (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id               uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  start_date            date NOT NULL,
  end_date              date,
  sequence              integer NOT NULL DEFAULT 1,
  position_id           uuid REFERENCES public.positions(id) ON DELETE SET NULL,
  department_id         uuid REFERENCES public.departments(id) ON DELETE SET NULL,
  location_id           uuid REFERENCES public.locations(id) ON DELETE SET NULL,
  job_classification_id uuid REFERENCES public.job_classifications(id) ON DELETE SET NULL,
  job_title             text NOT NULL,
  manager_id            uuid REFERENCES public.users(id) ON DELETE SET NULL,
  event_reason          text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  EXCLUDE USING gist (
    user_id WITH =,
    daterange(start_date, end_date, '[)') WITH &&
  )
);

CREATE INDEX IF NOT EXISTS idx_ec_job_info_tenant ON public.ec_job_information(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_job_info_user ON public.ec_job_information(user_id);
CREATE INDEX IF NOT EXISTS idx_ec_job_info_manager ON public.ec_job_information(manager_id);
CREATE INDEX IF NOT EXISTS idx_ec_job_info_position ON public.ec_job_information(position_id);
CREATE INDEX IF NOT EXISTS idx_ec_job_info_current ON public.ec_job_information(user_id) WHERE end_date IS NULL;

ALTER TABLE public.ec_job_information ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ec_job_information FORCE ROW LEVEL SECURITY;

CREATE POLICY ec_job_info_select ON public.ec_job_information
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY ec_job_info_insert ON public.ec_job_information
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());
CREATE POLICY ec_job_info_update ON public.ec_job_information
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

-- ═══════════════════════════════════════════════════════════════════
-- 3. EC_COMPENSATION: salary / pay records with effective dates
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  CREATE TYPE pay_frequency AS ENUM ('monthly', 'biweekly', 'weekly', 'annual');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.ec_compensation (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  start_date      date NOT NULL,
  end_date        date,
  sequence        integer NOT NULL DEFAULT 1,
  pay_group       text,
  currency        text NOT NULL DEFAULT 'MXN',
  base_salary     numeric(14,2) NOT NULL,
  frequency       pay_frequency NOT NULL DEFAULT 'monthly',
  bonus_target    numeric(5,2),
  event_reason    text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  EXCLUDE USING gist (
    user_id WITH =,
    daterange(start_date, end_date, '[)') WITH &&
  )
);

CREATE INDEX IF NOT EXISTS idx_ec_comp_tenant ON public.ec_compensation(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_comp_user ON public.ec_compensation(user_id);
CREATE INDEX IF NOT EXISTS idx_ec_comp_current ON public.ec_compensation(user_id) WHERE end_date IS NULL;

ALTER TABLE public.ec_compensation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ec_compensation FORCE ROW LEVEL SECURITY;

CREATE POLICY ec_comp_select ON public.ec_compensation
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY ec_comp_insert ON public.ec_compensation
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());
CREATE POLICY ec_comp_update ON public.ec_compensation
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

-- ═══════════════════════════════════════════════════════════════════
-- 4. EC_PERSONAL_INFORMATION: personal data with effective dates
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.ec_personal_information (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id           uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  start_date        date NOT NULL,
  end_date          date,
  sequence          integer NOT NULL DEFAULT 1,
  first_name        text NOT NULL,
  last_name         text NOT NULL,
  middle_name       text,
  date_of_birth     date,
  gender            text,
  marital_status    text,
  nationality       text,
  national_id       text,
  tax_id            text,
  phone             text,
  personal_email    text,
  address_line1     text,
  address_line2     text,
  city              text,
  state             text,
  postal_code       text,
  country           text DEFAULT 'MX',
  emergency_contact_name  text,
  emergency_contact_phone text,
  event_reason      text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  EXCLUDE USING gist (
    user_id WITH =,
    daterange(start_date, end_date, '[)') WITH &&
  )
);

CREATE INDEX IF NOT EXISTS idx_ec_personal_tenant ON public.ec_personal_information(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ec_personal_user ON public.ec_personal_information(user_id);
CREATE INDEX IF NOT EXISTS idx_ec_personal_current ON public.ec_personal_information(user_id) WHERE end_date IS NULL;

ALTER TABLE public.ec_personal_information ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ec_personal_information FORCE ROW LEVEL SECURITY;

CREATE POLICY ec_personal_select ON public.ec_personal_information
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY ec_personal_insert ON public.ec_personal_information
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());
CREATE POLICY ec_personal_update ON public.ec_personal_information
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

-- ═══════════════════════════════════════════════════════════════════
-- 5. FUNCTION: insert_effective_record
--    Atomically closes the current record and inserts a new one.
--    Works for any ec_* table with (user_id, start_date, end_date).
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.insert_effective_record(
  p_table   text,
  p_user_id uuid,
  p_data    jsonb,
  p_start   date DEFAULT CURRENT_DATE
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_id uuid;
  v_cols   text;
  v_vals   text;
  v_key    text;
  v_val    text;
  v_col_arr text[] := ARRAY[]::text[];
  v_val_arr text[] := ARRAY[]::text[];
BEGIN
  IF p_table NOT IN ('ec_job_information', 'ec_compensation', 'ec_personal_information') THEN
    RAISE EXCEPTION 'Invalid table: %', p_table;
  END IF;

  -- Close the currently open record for this user
  EXECUTE format(
    'UPDATE %I SET end_date = $1, updated_at = now() WHERE user_id = $2 AND end_date IS NULL',
    p_table
  ) USING p_start, p_user_id;

  -- Build column/value lists from the JSONB payload
  FOR v_key, v_val IN SELECT * FROM jsonb_each_text(p_data)
  LOOP
    IF v_key NOT IN ('id', 'created_at', 'updated_at', 'end_date') THEN
      v_col_arr := v_col_arr || quote_ident(v_key);
      v_val_arr := v_val_arr || quote_literal(v_val);
    END IF;
  END LOOP;

  v_cols := array_to_string(v_col_arr, ', ');
  v_vals := array_to_string(v_val_arr, ', ');

  -- Insert the new record
  EXECUTE format(
    'INSERT INTO %I (user_id, start_date, end_date, %s) VALUES ($1, $2, NULL, %s) RETURNING id',
    p_table, v_cols, v_vals
  ) USING p_user_id, p_start INTO v_new_id;

  RETURN v_new_id;
END;
$$;

REVOKE ALL ON FUNCTION public.insert_effective_record(text, uuid, jsonb, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.insert_effective_record(text, uuid, jsonb, date) TO authenticated;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT EXECUTE ON FUNCTION public.insert_effective_record(text, uuid, jsonb, date) TO prisma_app;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 6. HELPER: get record current at a specific date
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.effective_record_at(
  p_table   text,
  p_user_id uuid,
  p_date    date DEFAULT CURRENT_DATE
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_table NOT IN ('ec_job_information', 'ec_compensation', 'ec_personal_information') THEN
    RAISE EXCEPTION 'Invalid table: %', p_table;
  END IF;

  RETURN QUERY EXECUTE format(
    'SELECT to_jsonb(t) FROM %I t WHERE t.user_id = $1 AND t.start_date <= $2 AND (t.end_date IS NULL OR t.end_date > $2) LIMIT 1',
    p_table
  ) USING p_user_id, p_date;
END;
$$;

REVOKE ALL ON FUNCTION public.effective_record_at(text, uuid, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.effective_record_at(text, uuid, date) TO authenticated;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT EXECUTE ON FUNCTION public.effective_record_at(text, uuid, date) TO prisma_app;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 7. GRANTS on tables
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE ON public.ec_job_information      TO authenticated;
  GRANT SELECT, INSERT, UPDATE ON public.ec_compensation         TO authenticated;
  GRANT SELECT, INSERT, UPDATE ON public.ec_personal_information TO authenticated;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT SELECT, INSERT, UPDATE ON public.ec_job_information      TO prisma_app;
    GRANT SELECT, INSERT, UPDATE ON public.ec_compensation         TO prisma_app;
    GRANT SELECT, INSERT, UPDATE ON public.ec_personal_information TO prisma_app;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 8. SEED: Effective-dated records for 10 existing acme-corp users
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_tenant uuid := 'a0000000-0000-0000-0000-000000000001';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tenants WHERE id = v_tenant) THEN
    RAISE NOTICE 'No acme-corp tenant, skipping ec_effective_dated seed';
    RETURN;
  END IF;

  -- ── EC_JOB_INFORMATION ────────────────────────────────────────────
  -- User 01: Elena Martinez - CEO (position POS-001, dept d...001)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000001', '2020-01-15', '2022-06-01', 1, 'b0000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000004', 'ce100000-0000-0000-0000-000000000001', 'cc100000-0000-0000-0000-000000000004', 'HR Director', NULL, 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000001', '2022-06-01', NULL, 2, 'b0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'ce100000-0000-0000-0000-000000000001', 'cc100000-0000-0000-0000-000000000001', 'CEO', NULL, 'Promotion')
  ON CONFLICT DO NOTHING;

  -- User 02: Carlos Ruiz - CTO (position POS-002, dept d...002)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000002', '2020-03-01', NULL, 1, 'b0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', 'ce100000-0000-0000-0000-000000000001', 'cc100000-0000-0000-0000-000000000002', 'CTO', 'e0000000-0000-0000-0000-000000000001', 'Hire')
  ON CONFLICT DO NOTHING;

  -- User 03: Maria Lopez - VP Sales (position POS-003, dept d...003)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000003', '2021-01-10', NULL, 1, 'b0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000003', 'ce100000-0000-0000-0000-000000000002', 'cc100000-0000-0000-0000-000000000003', 'VP of Sales', 'e0000000-0000-0000-0000-000000000001', 'Hire')
  ON CONFLICT DO NOTHING;

  -- User 04: Ana Torres - HR Director (position POS-004, dept d...004)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000004', '2022-07-01', NULL, 1, 'b0000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000004', 'ce100000-0000-0000-0000-000000000001', 'cc100000-0000-0000-0000-000000000004', 'HR Director', 'e0000000-0000-0000-0000-000000000001', 'Hire')
  ON CONFLICT DO NOTHING;

  -- User 05: Pedro Sanchez - Frontend Lead (position POS-005, dept d...005)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000005', '2020-06-15', '2023-01-01', 1, 'b0000000-0000-0000-0000-000000000009', 'd0000000-0000-0000-0000-000000000005', 'ce100000-0000-0000-0000-000000000001', 'cc100000-0000-0000-0000-000000000007', 'Frontend Engineer', 'e0000000-0000-0000-0000-000000000002', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000005', '2023-01-01', NULL, 2, 'b0000000-0000-0000-0000-000000000005', 'd0000000-0000-0000-0000-000000000005', 'ce100000-0000-0000-0000-000000000001', 'cc100000-0000-0000-0000-000000000005', 'Frontend Lead', 'e0000000-0000-0000-0000-000000000002', 'Promotion')
  ON CONFLICT DO NOTHING;

  -- User 06: Laura Diaz - Backend Lead (position POS-006, dept d...006)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000006', '2020-08-01', NULL, 1, 'b0000000-0000-0000-0000-000000000006', 'd0000000-0000-0000-0000-000000000006', 'ce100000-0000-0000-0000-000000000002', 'cc100000-0000-0000-0000-000000000006', 'Backend Lead', 'e0000000-0000-0000-0000-000000000002', 'Hire')
  ON CONFLICT DO NOTHING;

  -- User 07: Roberto Garcia - Frontend Engineer (position POS-009, dept d...005)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000007', '2021-04-01', NULL, 1, 'b0000000-0000-0000-0000-000000000009', 'd0000000-0000-0000-0000-000000000005', 'ce100000-0000-0000-0000-000000000001', 'cc100000-0000-0000-0000-000000000007', 'Frontend Engineer', 'e0000000-0000-0000-0000-000000000005', 'Hire')
  ON CONFLICT DO NOTHING;

  -- User 08: Sofia Mendez - Backend Engineer (position POS-010, dept d...006)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000008', '2021-09-15', NULL, 1, 'b0000000-0000-0000-0000-000000000010', 'd0000000-0000-0000-0000-000000000006', 'ce100000-0000-0000-0000-000000000002', 'cc100000-0000-0000-0000-000000000007', 'Backend Engineer', 'e0000000-0000-0000-0000-000000000006', 'Hire')
  ON CONFLICT DO NOTHING;

  -- User 09: Diego Herrera - Sales Executive (position POS-011, dept d...003)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000009', '2022-02-01', NULL, 1, 'b0000000-0000-0000-0000-000000000011', 'd0000000-0000-0000-0000-000000000003', 'ce100000-0000-0000-0000-000000000002', 'cc100000-0000-0000-0000-000000000008', 'Sales Executive', 'e0000000-0000-0000-0000-000000000003', 'Hire')
  ON CONFLICT DO NOTHING;

  -- User 10: Lucia Flores - HR Specialist (position POS-008, dept d...004)
  INSERT INTO ec_job_information (tenant_id, user_id, start_date, end_date, sequence, position_id, department_id, location_id, job_classification_id, job_title, manager_id, event_reason)
  VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000010', '2022-05-01', NULL, 1, 'b0000000-0000-0000-0000-000000000008', 'd0000000-0000-0000-0000-000000000004', 'ce100000-0000-0000-0000-000000000001', 'cc100000-0000-0000-0000-000000000009', 'HR Specialist', 'e0000000-0000-0000-0000-000000000004', 'Hire')
  ON CONFLICT DO NOTHING;

  -- ── EC_COMPENSATION ───────────────────────────────────────────────
  INSERT INTO ec_compensation (tenant_id, user_id, start_date, end_date, sequence, currency, base_salary, frequency, bonus_target, event_reason) VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000001', '2020-01-15', '2022-06-01', 1, 'MXN', 85000.00, 'monthly', 10.00, 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000001', '2022-06-01', '2024-01-01', 2, 'MXN', 150000.00, 'monthly', 25.00, 'Promotion'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000001', '2024-01-01', NULL, 3, 'MXN', 180000.00, 'monthly', 30.00, 'Annual Review'),

    (v_tenant, 'e0000000-0000-0000-0000-000000000002', '2020-03-01', '2023-01-01', 1, 'MXN', 120000.00, 'monthly', 20.00, 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000002', '2023-01-01', NULL, 2, 'MXN', 140000.00, 'monthly', 20.00, 'Annual Review'),

    (v_tenant, 'e0000000-0000-0000-0000-000000000003', '2021-01-10', NULL, 1, 'MXN', 110000.00, 'monthly', 20.00, 'Hire'),

    (v_tenant, 'e0000000-0000-0000-0000-000000000004', '2022-07-01', NULL, 1, 'MXN', 90000.00, 'monthly', 15.00, 'Hire'),

    (v_tenant, 'e0000000-0000-0000-0000-000000000005', '2020-06-15', '2023-01-01', 1, 'MXN', 45000.00, 'monthly', 5.00, 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000005', '2023-01-01', NULL, 2, 'MXN', 70000.00, 'monthly', 10.00, 'Promotion'),

    (v_tenant, 'e0000000-0000-0000-0000-000000000006', '2020-08-01', NULL, 1, 'MXN', 72000.00, 'monthly', 10.00, 'Hire'),

    (v_tenant, 'e0000000-0000-0000-0000-000000000007', '2021-04-01', NULL, 1, 'MXN', 42000.00, 'monthly', 5.00, 'Hire'),

    (v_tenant, 'e0000000-0000-0000-0000-000000000008', '2021-09-15', NULL, 1, 'MXN', 44000.00, 'monthly', 5.00, 'Hire'),

    (v_tenant, 'e0000000-0000-0000-0000-000000000009', '2022-02-01', NULL, 1, 'MXN', 38000.00, 'monthly', 15.00, 'Hire'),

    (v_tenant, 'e0000000-0000-0000-0000-000000000010', '2022-05-01', NULL, 1, 'MXN', 35000.00, 'monthly', 5.00, 'Hire')
  ON CONFLICT DO NOTHING;

  -- ── EC_PERSONAL_INFORMATION ───────────────────────────────────────
  INSERT INTO ec_personal_information (tenant_id, user_id, start_date, end_date, sequence, first_name, last_name, date_of_birth, gender, nationality, national_id, phone, country, event_reason) VALUES
    (v_tenant, 'e0000000-0000-0000-0000-000000000001', '2020-01-15', NULL, 1, 'Elena', 'Martínez', '1985-03-12', 'F', 'Mexicana', 'MARE850312MDFXXX01', '+52 55 1234 0001', 'MX', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000002', '2020-03-01', NULL, 1, 'Carlos', 'Ruiz', '1982-07-25', 'M', 'Mexicana', 'RUIC820725HDFXXX02', '+52 55 1234 0002', 'MX', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000003', '2021-01-10', NULL, 1, 'María', 'López', '1988-11-08', 'F', 'Mexicana', 'LOPM881108MDFXXX03', '+52 33 1234 0003', 'MX', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000004', '2022-07-01', NULL, 1, 'Ana', 'Torres', '1990-05-20', 'F', 'Mexicana', 'TORA900520MDFXXX04', '+52 55 1234 0004', 'MX', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000005', '2020-06-15', NULL, 1, 'Pedro', 'Sánchez', '1993-09-15', 'M', 'Mexicana', 'SANP930915HDFXXX05', '+52 55 1234 0005', 'MX', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000006', '2020-08-01', NULL, 1, 'Laura', 'Díaz', '1991-01-30', 'F', 'Mexicana', 'DIAL910130MDFXXX06', '+52 33 1234 0006', 'MX', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000007', '2021-04-01', NULL, 1, 'Roberto', 'García', '1995-06-18', 'M', 'Mexicana', 'GARR950618HDFXXX07', '+52 55 1234 0007', 'MX', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000008', '2021-09-15', NULL, 1, 'Sofía', 'Méndez', '1994-12-03', 'F', 'Mexicana', 'MENS941203MDFXXX08', '+52 33 1234 0008', 'MX', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000009', '2022-02-01', NULL, 1, 'Diego', 'Herrera', '1992-08-22', 'M', 'Mexicana', 'HERD920822HDFXXX09', '+52 33 1234 0009', 'MX', 'Hire'),
    (v_tenant, 'e0000000-0000-0000-0000-000000000010', '2022-05-01', NULL, 1, 'Lucía', 'Flores', '1996-04-10', 'F', 'Mexicana', 'FLOL960410MDFXXX10', '+52 55 1234 0010', 'MX', 'Hire')
  ON CONFLICT DO NOTHING;

END $$;
