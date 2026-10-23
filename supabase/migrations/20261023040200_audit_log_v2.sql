-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Loop 3 — Step 6: Audit Log v2                                     ║
-- ║  Evolves the Phase 6 audit_logs table with entity tracking,        ║
-- ║  diff capture, and request metadata. INSERT-only for app roles.    ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════
-- 1. Add new columns to audit_logs
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE audit_logs
  ADD COLUMN IF NOT EXISTS entity      text,
  ADD COLUMN IF NOT EXISTS entity_id   text,
  ADD COLUMN IF NOT EXISTS diff        jsonb,
  ADD COLUMN IF NOT EXISTS ip          inet,
  ADD COLUMN IF NOT EXISTS user_agent  text;

-- Alias: rename user_id → actor_id conceptually (keep column for FK, add alias view)
-- We keep user_id as the physical column to preserve the FK, but expose actor_id in the API.
COMMENT ON COLUMN audit_logs.user_id IS 'actor_id: the user who performed the action';

-- ═══════════════════════════════════════════════════════════════════
-- 2. Indexes for new columns
-- ═══════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity, entity_id);

-- ═══════════════════════════════════════════════════════════════════
-- 3. Ensure INSERT-only for app roles
--    The Phase 6 migration already has:
--      - audit_logs_select (admin read)
--      - audit_logs_insert (all authenticated)
--      - No UPDATE or DELETE policies
--    We reinforce with RESTRICTIVE policies to block UPDATE/DELETE
--    even if someone adds a permissive policy later.
-- ═══════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'audit_logs'
      AND policyname = 'no_update_audit_logs'
  ) THEN
    EXECUTE 'CREATE POLICY no_update_audit_logs ON audit_logs
      AS RESTRICTIVE FOR UPDATE TO authenticated USING (false)';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'audit_logs'
      AND policyname = 'no_delete_audit_logs'
  ) THEN
    EXECUTE 'CREATE POLICY no_delete_audit_logs ON audit_logs
      AS RESTRICTIVE FOR DELETE TO authenticated USING (false)';
  END IF;
END $$;

-- Ensure FORCE RLS is on
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;

-- Also block prisma_app from UPDATE/DELETE on audit_logs
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    REVOKE UPDATE, DELETE ON audit_logs FROM prisma_app;
    GRANT SELECT, INSERT ON audit_logs TO prisma_app;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 4. Log helper function (called from server code)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION write_audit_log(
  p_tenant_id  uuid,
  p_actor_id   uuid,
  p_action     text,
  p_entity     text DEFAULT NULL,
  p_entity_id  text DEFAULT NULL,
  p_diff       jsonb DEFAULT NULL,
  p_ip         inet DEFAULT NULL,
  p_user_agent text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.audit_logs (
    tenant_id, user_id, action, entity, entity_id, diff, ip, user_agent
  ) VALUES (
    p_tenant_id, p_actor_id, p_action, p_entity, p_entity_id, p_diff, p_ip, p_user_agent
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION write_audit_log FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION write_audit_log FROM anon;
GRANT EXECUTE ON FUNCTION write_audit_log TO authenticated;
GRANT EXECUTE ON FUNCTION write_audit_log TO service_role;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT EXECUTE ON FUNCTION write_audit_log TO prisma_app;
  END IF;
END $$;
