-- Fix: revoke public EXECUTE on SECURITY DEFINER function rls_auto_enable()
--
-- rls_auto_enable() runs with owner (postgres) privileges. The anon and
-- authenticated roles can currently call it via PostgREST, which is a
-- privilege-escalation vector.  The function is only meant to be invoked
-- by the event trigger "ensure_rls" (ddl_command_end), which PostgreSQL
-- fires with the trigger owner's privileges, so revoking EXECUTE from
-- API-facing roles does not affect the event trigger.

-- Guard: rls_auto_enable() may not exist on a fresh db reset (it was
-- created manually on the original instance, not via a migration).
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
