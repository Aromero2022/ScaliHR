-- Fix: revoke public EXECUTE on SECURITY DEFINER function rls_auto_enable()
--
-- rls_auto_enable() runs with owner (postgres) privileges. The anon and
-- authenticated roles can currently call it via PostgREST, which is a
-- privilege-escalation vector.  The function is only meant to be invoked
-- by the event trigger "ensure_rls" (ddl_command_end), which PostgreSQL
-- fires with the trigger owner's privileges, so revoking EXECUTE from
-- API-facing roles does not affect the event trigger.

-- 1. Revoke from the catch-all PUBLIC pseudo-role (covers any future roles too)
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC;

-- 2. Explicitly revoke from API-facing roles
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM anon;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM authenticated;

-- 3. Grant only to service_role (admin-level API access)
GRANT EXECUTE ON FUNCTION public.rls_auto_enable() TO service_role;
