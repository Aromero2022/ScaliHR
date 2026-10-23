-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  D2 — Tenant in the JWT                                           ║
-- ║  custom_access_token_hook injects tenant_id + app_role into JWT.  ║
-- ║  current_tenant_id() reads from the enriched token.               ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════
-- 1. USER TENANT MEMBERSHIPS
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.user_tenant_memberships (
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id  uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  app_role   text NOT NULL DEFAULT 'member',
  is_active  boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_utm_tenant ON public.user_tenant_memberships(tenant_id);
CREATE INDEX IF NOT EXISTS idx_utm_user   ON public.user_tenant_memberships(user_id);

ALTER TABLE public.user_tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_tenant_memberships FORCE ROW LEVEL SECURITY;

CREATE POLICY "utm_own_read" ON public.user_tenant_memberships
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "utm_service_bypass" ON public.user_tenant_memberships
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════════
-- 2. USER SETTINGS
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id           uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  active_tenant_id  uuid REFERENCES public.tenants(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings FORCE ROW LEVEL SECURITY;

CREATE POLICY "us_own_read" ON public.user_settings
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "us_own_update" ON public.user_settings
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "us_own_insert" ON public.user_settings
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "us_service_bypass" ON public.user_settings
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════════
-- 3. CUSTOM ACCESS TOKEN HOOK
-- ═══════════════════════════════════════════════════════════════════
-- SECURITY DEFINER: runs as the function owner (postgres).
-- search_path = '' prevents hijacking via schema search path.
-- Only supabase_auth_admin may EXECUTE.

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  claims      jsonb;
  user_id     uuid;
  tenant_id   uuid;
  app_role    text;
BEGIN
  claims  := event->'claims';
  user_id := (event->>'user_id')::uuid;

  -- Resolve active tenant from user_settings
  SELECT us.active_tenant_id INTO tenant_id
  FROM public.user_settings us
  WHERE us.user_id = custom_access_token_hook.user_id;

  -- If no active tenant, pick the first active membership
  IF tenant_id IS NULL THEN
    SELECT utm.tenant_id INTO tenant_id
    FROM public.user_tenant_memberships utm
    WHERE utm.user_id = custom_access_token_hook.user_id
      AND utm.is_active = true
    ORDER BY utm.created_at
    LIMIT 1;
  END IF;

  -- Resolve the app_role for this tenant
  IF tenant_id IS NOT NULL THEN
    SELECT utm.app_role INTO app_role
    FROM public.user_tenant_memberships utm
    WHERE utm.user_id = custom_access_token_hook.user_id
      AND utm.tenant_id = custom_access_token_hook.tenant_id
      AND utm.is_active = true;
  END IF;

  -- Inject claims
  claims := jsonb_set(claims, '{tenant_id}', to_jsonb(COALESCE(tenant_id::text, '')));
  claims := jsonb_set(claims, '{app_role}',  to_jsonb(COALESCE(app_role, 'member')));

  event := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$;

-- Lock down execution: only supabase_auth_admin
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) TO supabase_auth_admin;

-- Grant SELECT on the tables the hook reads
GRANT SELECT ON TABLE public.user_settings TO supabase_auth_admin;
GRANT SELECT ON TABLE public.user_tenant_memberships TO supabase_auth_admin;

-- ═══════════════════════════════════════════════════════════════════
-- 4. current_tenant_id() — reads from the enriched JWT
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    -- Primary: root-level claim injected by custom_access_token_hook
    NULLIF(
      (current_setting('request.jwt.claims', true)::json->>'tenant_id'),
      ''
    )::uuid,
    -- Fallback: app_metadata path (pre-hook or raw_app_meta_data flow)
    (current_setting('request.jwt.claims', true)::json->'app_metadata'->>'tenant_id')::uuid
  );
$$;

-- Lock down: only authenticated and service_role
REVOKE EXECUTE ON FUNCTION public.current_tenant_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_tenant_id() FROM anon;
GRANT  EXECUTE ON FUNCTION public.current_tenant_id() TO authenticated;
GRANT  EXECUTE ON FUNCTION public.current_tenant_id() TO service_role;

-- ═══════════════════════════════════════════════════════════════════
-- 5. SEED: Memberships for demo users
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_tenant uuid := 'a0000000-0000-0000-0000-000000000001';
BEGIN
  -- Elena Martinez (HR admin)
  INSERT INTO public.user_tenant_memberships (user_id, tenant_id, app_role)
  VALUES ('f0000000-0000-0000-0000-000000000001', v_tenant, 'admin')
  ON CONFLICT (user_id, tenant_id) DO NOTHING;

  INSERT INTO public.user_settings (user_id, active_tenant_id)
  VALUES ('f0000000-0000-0000-0000-000000000001', v_tenant)
  ON CONFLICT (user_id) DO NOTHING;

  -- Seed memberships for other demo auth users if they exist
  INSERT INTO public.user_tenant_memberships (user_id, tenant_id, app_role)
  SELECT au.id, v_tenant, 'member'
  FROM auth.users au
  WHERE au.id != 'f0000000-0000-0000-0000-000000000001'
    AND NOT EXISTS (
      SELECT 1 FROM public.user_tenant_memberships utm
      WHERE utm.user_id = au.id AND utm.tenant_id = v_tenant
    );

  -- Set active tenant for users that don't have one
  INSERT INTO public.user_settings (user_id, active_tenant_id)
  SELECT au.id, v_tenant
  FROM auth.users au
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_settings us WHERE us.user_id = au.id
  );
END $$;
