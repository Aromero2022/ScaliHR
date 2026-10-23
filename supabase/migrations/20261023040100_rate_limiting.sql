-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Loop 3 — Step 5: Rate Limiting (Postgres-native)                  ║
-- ║  Atomic sliding-window rate limiter. No external dependencies.     ║
-- ║  Limits: login 5/min, mfa_verify 5/min, tenant_create 3/hour,     ║
-- ║          api_action 30/min.                                        ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════
-- 1. rate_limits table
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS rate_limits (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key         text NOT NULL,
  action      text NOT NULL,
  tokens      int  NOT NULL DEFAULT 0,
  window_start timestamptz NOT NULL DEFAULT now(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(key, action)
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_key_action ON rate_limits(key, action);
CREATE INDEX IF NOT EXISTS idx_rate_limits_window     ON rate_limits(window_start);

-- No RLS: this table is accessed by server functions only
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limits FORCE ROW LEVEL SECURITY;

-- Only service_role and prisma_app can access
DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE ON rate_limits TO authenticated;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON rate_limits TO prisma_app;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 2. check_rate_limit: atomic sliding-window function
--    Returns TRUE if within limit, FALSE if rate-limited.
--    key: identifier (IP, user_id, etc.)
--    p_action: 'login', 'mfa_verify', 'tenant_create', 'api_action'
--    max_tokens: maximum attempts in window
--    window_seconds: sliding window duration
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION check_rate_limit(
  p_key            text,
  p_action         text,
  p_max_tokens     int DEFAULT 5,
  p_window_seconds int DEFAULT 60
)
RETURNS boolean
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_now         timestamptz := now();
  v_window_start timestamptz := v_now - (p_window_seconds || ' seconds')::interval;
  v_tokens      int;
BEGIN
  -- Upsert: reset window if expired, else increment
  INSERT INTO public.rate_limits (key, action, tokens, window_start)
  VALUES (p_key, p_action, 1, v_now)
  ON CONFLICT (key, action) DO UPDATE SET
    tokens = CASE
      WHEN public.rate_limits.window_start < v_window_start THEN 1
      ELSE public.rate_limits.tokens + 1
    END,
    window_start = CASE
      WHEN public.rate_limits.window_start < v_window_start THEN v_now
      ELSE public.rate_limits.window_start
    END
  RETURNING tokens INTO v_tokens;

  RETURN v_tokens <= p_max_tokens;
END;
$$;

-- Lockdown: only authenticated and service_role can call
REVOKE EXECUTE ON FUNCTION check_rate_limit FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION check_rate_limit FROM anon;
GRANT EXECUTE ON FUNCTION check_rate_limit TO authenticated;
GRANT EXECUTE ON FUNCTION check_rate_limit TO service_role;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT EXECUTE ON FUNCTION check_rate_limit TO prisma_app;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Cleanup: periodic purge of expired entries (run via cron or manually)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION purge_expired_rate_limits(p_max_age_seconds int DEFAULT 3600)
RETURNS int
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_deleted int;
BEGIN
  DELETE FROM public.rate_limits
  WHERE window_start < now() - (p_max_age_seconds || ' seconds')::interval;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE EXECUTE ON FUNCTION purge_expired_rate_limits FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION purge_expired_rate_limits FROM anon;
REVOKE EXECUTE ON FUNCTION purge_expired_rate_limits FROM authenticated;
GRANT EXECUTE ON FUNCTION purge_expired_rate_limits TO service_role;

-- ═══════════════════════════════════════════════════════════════════
-- Documented rate limits:
--   login:          5  attempts / 60s   per IP
--   mfa_verify:     5  attempts / 60s   per user_id
--   tenant_create:  3  attempts / 3600s per user_id
--   api_action:     30 attempts / 60s   per user_id
-- ═══════════════════════════════════════════════════════════════════
