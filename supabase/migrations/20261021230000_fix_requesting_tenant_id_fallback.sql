-- Fix requesting_tenant_id() to support both hook-enabled and raw_app_meta_data paths.
--
-- When the custom_access_token_hook is enabled, tenant_id lives at the JWT root.
-- When it is NOT enabled, GoTrue copies raw_app_meta_data into app_metadata,
-- so tenant_id is at jwt->'app_metadata'->>'tenant_id'.
-- COALESCE tries the root-level claim first, then falls back to app_metadata.

CREATE OR REPLACE FUNCTION public.requesting_tenant_id()
RETURNS uuid
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(
    (current_setting('request.jwt.claims', true)::json->>'tenant_id')::uuid,
    (current_setting('request.jwt.claims', true)::json->'app_metadata'->>'tenant_id')::uuid
  )
$$;
