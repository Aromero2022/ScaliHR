-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  MIGRATION: init_full_suite_rls                                     ║
-- ║  Multi-tenant RLS isolation for all ScaliaHR suite tables           ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ─── HELPER: extract tenant_id from the JWT claim ───────────────────
CREATE OR REPLACE FUNCTION public.requesting_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT (current_setting('request.jwt.claims', true)::json ->> 'tenant_id')::uuid;
$$;

-- ─── ENABLE RLS ON ALL SUITE TABLES ─────────────────────────────────

ALTER TABLE IF EXISTS public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.job_informations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.performance_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.continuous_feedbacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.talent_pools ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.talent_pool_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.succession_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.succession_nominees ENABLE ROW LEVEL SECURITY;

-- ─── TENANT TABLE ───────────────────────────────────────────────────
-- Tenants can only see their own record
CREATE POLICY tenant_isolation_select ON public.tenants
  FOR SELECT USING (id = public.requesting_tenant_id());

CREATE POLICY tenant_isolation_all ON public.tenants
  FOR ALL USING (id = public.requesting_tenant_id());

-- ─── USERS ──────────────────────────────────────────────────────────
CREATE POLICY users_tenant_select ON public.users
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY users_tenant_insert ON public.users
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());

CREATE POLICY users_tenant_update ON public.users
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY users_tenant_delete ON public.users
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── DEPARTMENTS ────────────────────────────────────────────────────
CREATE POLICY departments_tenant_select ON public.departments
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY departments_tenant_insert ON public.departments
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());

CREATE POLICY departments_tenant_update ON public.departments
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY departments_tenant_delete ON public.departments
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── JOB INFORMATIONS ──────────────────────────────────────────────
CREATE POLICY job_informations_tenant_select ON public.job_informations
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY job_informations_tenant_insert ON public.job_informations
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());

CREATE POLICY job_informations_tenant_update ON public.job_informations
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY job_informations_tenant_delete ON public.job_informations
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── PERFORMANCE GOALS ─────────────────────────────────────────────
CREATE POLICY goals_tenant_select ON public.performance_goals
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY goals_tenant_insert ON public.performance_goals
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());

CREATE POLICY goals_tenant_update ON public.performance_goals
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY goals_tenant_delete ON public.performance_goals
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── CONTINUOUS FEEDBACKS ───────────────────────────────────────────
-- Intra-tenant: any authenticated user can read/write feedback within
-- their own tenant boundary
CREATE POLICY feedback_tenant_select ON public.continuous_feedbacks
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY feedback_tenant_insert ON public.continuous_feedbacks
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());

CREATE POLICY feedback_tenant_update ON public.continuous_feedbacks
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY feedback_tenant_delete ON public.continuous_feedbacks
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── TALENT POOLS ───────────────────────────────────────────────────
CREATE POLICY talent_pools_tenant_select ON public.talent_pools
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY talent_pools_tenant_insert ON public.talent_pools
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());

CREATE POLICY talent_pools_tenant_update ON public.talent_pools
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY talent_pools_tenant_delete ON public.talent_pools
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── TALENT POOL ENTRIES ────────────────────────────────────────────
-- Isolation via join: entry belongs to a pool that belongs to a tenant
CREATE POLICY pool_entries_tenant_select ON public.talent_pool_entries
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.talent_pools tp
      WHERE tp.id = talent_pool_id
        AND tp.tenant_id = public.requesting_tenant_id()
    )
  );

CREATE POLICY pool_entries_tenant_insert ON public.talent_pool_entries
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.talent_pools tp
      WHERE tp.id = talent_pool_id
        AND tp.tenant_id = public.requesting_tenant_id()
    )
  );

CREATE POLICY pool_entries_tenant_update ON public.talent_pool_entries
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.talent_pools tp
      WHERE tp.id = talent_pool_id
        AND tp.tenant_id = public.requesting_tenant_id()
    )
  );

CREATE POLICY pool_entries_tenant_delete ON public.talent_pool_entries
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.talent_pools tp
      WHERE tp.id = talent_pool_id
        AND tp.tenant_id = public.requesting_tenant_id()
    )
  );

-- ─── SUCCESSION PLANS ──────────────────────────────────────────────
CREATE POLICY succession_plans_tenant_select ON public.succession_plans
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY succession_plans_tenant_insert ON public.succession_plans
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());

CREATE POLICY succession_plans_tenant_update ON public.succession_plans
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY succession_plans_tenant_delete ON public.succession_plans
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── SUCCESSION NOMINEES ────────────────────────────────────────────
CREATE POLICY nominees_tenant_select ON public.succession_nominees
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.succession_plans sp
      WHERE sp.id = succession_plan_id
        AND sp.tenant_id = public.requesting_tenant_id()
    )
  );

CREATE POLICY nominees_tenant_insert ON public.succession_nominees
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.succession_plans sp
      WHERE sp.id = succession_plan_id
        AND sp.tenant_id = public.requesting_tenant_id()
    )
  );

CREATE POLICY nominees_tenant_update ON public.succession_nominees
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.succession_plans sp
      WHERE sp.id = succession_plan_id
        AND sp.tenant_id = public.requesting_tenant_id()
    )
  );

CREATE POLICY nominees_tenant_delete ON public.succession_nominees
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.succession_plans sp
      WHERE sp.id = succession_plan_id
        AND sp.tenant_id = public.requesting_tenant_id()
    )
  );

-- ─── SERVICE_ROLE BYPASS ────────────────────────────────────────────
-- service_role needs unrestricted access for backend operations
ALTER TABLE public.tenants FORCE ROW LEVEL SECURITY;
ALTER TABLE public.users FORCE ROW LEVEL SECURITY;
ALTER TABLE public.departments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.job_informations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.performance_goals FORCE ROW LEVEL SECURITY;
ALTER TABLE public.continuous_feedbacks FORCE ROW LEVEL SECURITY;
ALTER TABLE public.talent_pools FORCE ROW LEVEL SECURITY;
ALTER TABLE public.talent_pool_entries FORCE ROW LEVEL SECURITY;
ALTER TABLE public.succession_plans FORCE ROW LEVEL SECURITY;
ALTER TABLE public.succession_nominees FORCE ROW LEVEL SECURITY;

-- ─── REMEDIACIÓN CRÍTICA: SECURITY DEFINER LOCKDOWN ─────────────────
-- Re-apply the rls_auto_enable() permission fix (idempotent)
-- Guard: function may not exist on a fresh db reset
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'rls_auto_enable'
  ) THEN
    REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC;
    REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM anon;
    REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM authenticated;
    GRANT  EXECUTE ON FUNCTION public.rls_auto_enable() TO service_role;
  END IF;
END $$;

-- Lock down the tenant_id helper too
REVOKE EXECUTE ON FUNCTION public.requesting_tenant_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.requesting_tenant_id() FROM anon;
GRANT EXECUTE ON FUNCTION public.requesting_tenant_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.requesting_tenant_id() TO service_role;
