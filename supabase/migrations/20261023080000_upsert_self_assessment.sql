-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  upsert_self_assessment — SECURITY DEFINER RPC for self-assessment ║
-- ║  Ensures only the authenticated user can assess their own skills.  ║
-- ╚══════════════════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION public.upsert_self_assessment(
  p_skill_id uuid,
  p_level    smallint
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_tenant_id uuid;
  v_user_id   uuid;
  v_old_level smallint;
BEGIN
  -- Resolve actor from JWT
  SELECT u.id, u.tenant_id INTO v_user_id, v_tenant_id
  FROM public.users u
  WHERE u.auth_uid = auth.uid()
    AND u.tenant_id = public.requesting_tenant_id()
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Validate level
  IF p_level < 1 OR p_level > 5 THEN
    RAISE EXCEPTION 'Level must be between 1 and 5';
  END IF;

  -- Capture old level for audit
  SELECT es.self_assessed_level INTO v_old_level
  FROM public.employee_skills es
  WHERE es.tenant_id = v_tenant_id
    AND es.user_id   = v_user_id
    AND es.skill_id  = p_skill_id;

  -- Upsert: only self_assessed columns, never manager columns
  INSERT INTO public.employee_skills (
    tenant_id, user_id, skill_id,
    self_assessed_level, self_assessed_at,
    created_at, updated_at
  ) VALUES (
    v_tenant_id, v_user_id, p_skill_id,
    p_level, now(),
    now(), now()
  )
  ON CONFLICT (tenant_id, user_id, skill_id) DO UPDATE SET
    self_assessed_level = EXCLUDED.self_assessed_level,
    self_assessed_at    = now(),
    updated_at          = now();

  -- Audit log
  PERFORM public.write_audit_log(
    v_tenant_id,
    v_user_id,
    'tih.self_assessment',
    'employee_skills',
    v_user_id::text || ':' || p_skill_id::text,
    jsonb_build_object('old_level', v_old_level, 'new_level', p_level)
  );
END;
$$;

-- Privileges: only authenticated can call; revoke from public/anon
REVOKE EXECUTE ON FUNCTION public.upsert_self_assessment FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.upsert_self_assessment FROM anon;
GRANT  EXECUTE ON FUNCTION public.upsert_self_assessment TO authenticated;

-- Grant to prisma_app if it exists
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT EXECUTE ON FUNCTION public.upsert_self_assessment TO prisma_app;
  END IF;
END $$;
