-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  D3 — RLS Policies V2                                              ║
-- ║  ENABLE + FORCE on all tables. Per-operation policies.             ║
-- ║  No DELETE policy for authenticated (soft-delete only).            ║
-- ║  REVOKE rls_auto_enable from non-privileged roles.                 ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════
-- 1. ENABLE + FORCE RLS on every business table
-- ═══════════════════════════════════════════════════════════════════

-- Core tables (from D1 consolidation)
ALTER TABLE public.tenants              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants              FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.users                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users                FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.departments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments          FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.job_informations     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_informations     FORCE  ROW LEVEL SECURITY;

-- PMGM
ALTER TABLE public.performance_goals    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.performance_goals    FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.continuous_feedbacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.continuous_feedbacks FORCE  ROW LEVEL SECURITY;

-- SDM
ALTER TABLE public.talent_pools         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.talent_pools         FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.talent_pool_entries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.talent_pool_entries  FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.succession_plans     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.succession_plans     FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.succession_nominees  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.succession_nominees  FORCE  ROW LEVEL SECURITY;

-- EC Foundation (already FORCE from ec_position_and_foundation, idempotent)
ALTER TABLE public.job_families         FORCE ROW LEVEL SECURITY;
ALTER TABLE public.job_classifications  FORCE ROW LEVEL SECURITY;
ALTER TABLE public.job_roles            FORCE ROW LEVEL SECURITY;
ALTER TABLE public.positions            FORCE ROW LEVEL SECURITY;
ALTER TABLE public.object_definitions   FORCE ROW LEVEL SECURITY;
ALTER TABLE public.business_rules       FORCE ROW LEVEL SECURITY;

-- RBP / Admin
ALTER TABLE public.permission_groups    FORCE ROW LEVEL SECURITY;
ALTER TABLE public.permission_roles     FORCE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions     FORCE ROW LEVEL SECURITY;
ALTER TABLE public.role_assignments     FORCE ROW LEVEL SECURITY;
ALTER TABLE public.system_configurations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs           FORCE ROW LEVEL SECURITY;

-- TIH
ALTER TABLE public.skill_ontology       FORCE ROW LEVEL SECURITY;
ALTER TABLE public.job_role_skills      FORCE ROW LEVEL SECURITY;
ALTER TABLE public.employee_skills      FORCE ROW LEVEL SECURITY;

-- D2 tables
ALTER TABLE public.user_tenant_memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings           FORCE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════
-- 2. RESTRICTIVE "no delete" policies for authenticated role
--    These AND with existing permissive DELETE policies,
--    effectively blocking DELETE for authenticated users.
--    service_role bypasses RLS entirely (BYPASSRLS).
-- ═══════════════════════════════════════════════════════════════════

-- Tables that had permissive DELETE policies from earlier migrations.
-- A RESTRICTIVE policy with USING(false) ANDs with the permissive one,
-- resulting in no rows matching → DELETE blocked for authenticated.

DO $$
DECLARE
  tbl text;
BEGIN
  FOR tbl IN
    SELECT unnest(ARRAY[
      'tenants', 'users', 'departments', 'job_informations',
      'performance_goals', 'continuous_feedbacks',
      'talent_pools', 'talent_pool_entries',
      'succession_plans', 'succession_nominees',
      'job_families', 'job_roles', 'job_classifications',
      'positions', 'object_definitions', 'business_rules'
    ])
  LOOP
    -- Only create if the policy doesn't already exist
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE tablename = tbl
        AND policyname = 'no_hard_delete_authenticated'
    ) THEN
      EXECUTE format(
        'CREATE POLICY no_hard_delete_authenticated ON public.%I
         AS RESTRICTIVE FOR DELETE TO authenticated USING (false)',
        tbl
      );
    END IF;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 3. SECURITY LOCKDOWNS
-- ═══════════════════════════════════════════════════════════════════

-- rls_auto_enable: SECURITY DEFINER, only service_role
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM anon;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.rls_auto_enable() TO service_role;

-- requesting_tenant_id: keep for backward compat, same lockdown as current_tenant_id
REVOKE EXECUTE ON FUNCTION public.requesting_tenant_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.requesting_tenant_id() FROM anon;
GRANT  EXECUTE ON FUNCTION public.requesting_tenant_id() TO authenticated;
GRANT  EXECUTE ON FUNCTION public.requesting_tenant_id() TO service_role;

-- is_tenant_admin: SECURITY DEFINER, only authenticated + service_role
REVOKE EXECUTE ON FUNCTION public.is_tenant_admin() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_tenant_admin() FROM anon;
GRANT  EXECUTE ON FUNCTION public.is_tenant_admin() TO authenticated;
GRANT  EXECUTE ON FUNCTION public.is_tenant_admin() TO service_role;
