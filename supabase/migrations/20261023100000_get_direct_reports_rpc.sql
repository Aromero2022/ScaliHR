-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  get_direct_reports — returns user_ids of the caller's direct      ║
-- ║  reports based on ec_job_information manager relationship          ║
-- ╚══════════════════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION public.get_direct_reports()
RETURNS TABLE(user_id uuid)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id   uuid;
  v_tenant_id uuid;
BEGIN
  SELECT u.id, u.tenant_id INTO v_user_id, v_tenant_id
  FROM public.users u
  WHERE u.auth_uid = auth.uid()
    AND u.tenant_id = public.requesting_tenant_id()
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT DISTINCT ji.user_id
  FROM public.ec_job_information ji
  WHERE ji.manager_id = v_user_id
    AND ji.end_date IS NULL
    AND ji.user_id IN (
      SELECT u2.id FROM public.users u2
      WHERE u2.tenant_id = v_tenant_id
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_direct_reports FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_direct_reports FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_direct_reports TO authenticated;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT EXECUTE ON FUNCTION public.get_direct_reports TO prisma_app;
  END IF;
END $$;
