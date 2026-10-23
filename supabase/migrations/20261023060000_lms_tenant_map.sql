-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  LMS Tenant Map — maps tenants to Moodle categories & cohorts     ║
-- ║  Created when LMS is activated for a tenant via moodle-bootstrap  ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ─── lms_tenant_map ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.lms_tenant_map (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  moodle_category_id  integer NOT NULL,
  moodle_cohort_id    integer NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_lms_tenant_map_tenant
  ON public.lms_tenant_map(tenant_id);

-- ─── lms_user_map — maps Supabase user → Moodle user ID ────────────
CREATE TABLE IF NOT EXISTS public.lms_user_map (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  moodle_user_id  integer NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_lms_user_map_tenant
  ON public.lms_user_map(tenant_id);
CREATE INDEX IF NOT EXISTS idx_lms_user_map_user
  ON public.lms_user_map(user_id);

-- ═══════════════════════════════════════════════════════════════════
-- RLS
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE public.lms_tenant_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lms_tenant_map FORCE ROW LEVEL SECURITY;

ALTER TABLE public.lms_user_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lms_user_map FORCE ROW LEVEL SECURITY;

-- Tenant map: users can read their own tenant's mapping
CREATE POLICY lms_tenant_map_select ON public.lms_tenant_map
  FOR SELECT TO authenticated
  USING (
    tenant_id = (
      (current_setting('request.jwt.claims', true)::jsonb) ->> 'tenant_id'
    )::uuid
  );

-- User map: users can read their own tenant's user mappings
CREATE POLICY lms_user_map_select ON public.lms_user_map
  FOR SELECT TO authenticated
  USING (
    tenant_id = (
      (current_setting('request.jwt.claims', true)::jsonb) ->> 'tenant_id'
    )::uuid
  );

-- Insert/update only from server (prisma_app role inherits authenticated)
CREATE POLICY lms_tenant_map_insert ON public.lms_tenant_map
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = (
      (current_setting('request.jwt.claims', true)::jsonb) ->> 'tenant_id'
    )::uuid
  );

CREATE POLICY lms_tenant_map_update ON public.lms_tenant_map
  FOR UPDATE TO authenticated
  USING (
    tenant_id = (
      (current_setting('request.jwt.claims', true)::jsonb) ->> 'tenant_id'
    )::uuid
  )
  WITH CHECK (
    tenant_id = (
      (current_setting('request.jwt.claims', true)::jsonb) ->> 'tenant_id'
    )::uuid
  );

CREATE POLICY lms_user_map_insert ON public.lms_user_map
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = (
      (current_setting('request.jwt.claims', true)::jsonb) ->> 'tenant_id'
    )::uuid
  );

CREATE POLICY lms_user_map_update ON public.lms_user_map
  FOR UPDATE TO authenticated
  USING (
    tenant_id = (
      (current_setting('request.jwt.claims', true)::jsonb) ->> 'tenant_id'
    )::uuid
  )
  WITH CHECK (
    tenant_id = (
      (current_setting('request.jwt.claims', true)::jsonb) ->> 'tenant_id'
    )::uuid
  );

-- No DELETE policy for authenticated (soft delete only, per security rules)
