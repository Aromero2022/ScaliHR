-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  TIH Skills Hardening                                              ║
-- ║  Fixes D1 compliance: composite FKs, FORCE RLS, column privileges, ║
-- ║  CHECK constraints replacing enums, set_manager_assessment fn.     ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════
-- 0. UNIQUE(tenant_id, id) on referenced tables for composite FKs
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE skill_ontology
  ADD CONSTRAINT skill_ontology_tenant_id_uniq UNIQUE (tenant_id, id);

DO $$ BEGIN
  ALTER TABLE job_roles
    ADD CONSTRAINT job_roles_tenant_id_uniq UNIQUE (tenant_id, id);
EXCEPTION WHEN duplicate_table THEN NULL;
          WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE users
    ADD CONSTRAINT users_tenant_id_uniq UNIQUE (tenant_id, id);
EXCEPTION WHEN duplicate_table THEN NULL;
          WHEN duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 1. SKILL_ONTOLOGY — replace enum with CHECK, add name uniqueness
-- ═══════════════════════════════════════════════════════════════════

-- Convert enum → text first so UPDATE can use lowercase values
ALTER TABLE skill_ontology
  ALTER COLUMN category TYPE text USING category::text;

-- Normalise legacy uppercase enum values to lowercase categories
UPDATE skill_ontology SET category = 'technical'  WHERE category IN ('TECHNICAL', 'FUNCTIONAL', 'CERTIFICATION');
UPDATE skill_ontology SET category = 'soft'       WHERE category IN ('LEADERSHIP', 'INTERPERSONAL');
UPDATE skill_ontology SET category = 'language'   WHERE category = 'LANGUAGE';

ALTER TABLE skill_ontology
  ADD CONSTRAINT skill_ontology_category_chk
    CHECK (category IN ('technical', 'soft', 'language'));

CREATE UNIQUE INDEX IF NOT EXISTS idx_skill_ontology_tenant_name
  ON skill_ontology (tenant_id, lower(name));

-- ═══════════════════════════════════════════════════════════════════
-- 2. JOB_ROLE_SKILLS — composite PK, drop enum, composite FKs
-- ═══════════════════════════════════════════════════════════════════

-- Drop old FKs (auto-generated names: {table}_{column}_fkey)
ALTER TABLE job_role_skills DROP CONSTRAINT IF EXISTS job_role_skills_tenant_id_fkey;
ALTER TABLE job_role_skills DROP CONSTRAINT IF EXISTS job_role_skills_job_role_id_fkey;
ALTER TABLE job_role_skills DROP CONSTRAINT IF EXISTS job_role_skills_skill_id_fkey;

-- Drop old unique and PK
ALTER TABLE job_role_skills DROP CONSTRAINT IF EXISTS job_role_skills_job_role_id_skill_id_key;
ALTER TABLE job_role_skills DROP CONSTRAINT IF EXISTS job_role_skills_pkey;

-- Drop surrogate id
ALTER TABLE job_role_skills DROP COLUMN IF EXISTS id;

-- Rename required_level → required_proficiency_level (smallint + CHECK)
ALTER TABLE job_role_skills
  ALTER COLUMN required_level TYPE smallint;
ALTER TABLE job_role_skills
  RENAME COLUMN required_level TO required_proficiency_level;
ALTER TABLE job_role_skills
  ADD CONSTRAINT jrs_proficiency_chk CHECK (required_proficiency_level BETWEEN 1 AND 5);

-- Drop importance column & enum
ALTER TABLE job_role_skills DROP COLUMN IF EXISTS importance;

-- Composite PK
ALTER TABLE job_role_skills ADD PRIMARY KEY (tenant_id, job_role_id, skill_id);

-- Composite FKs
ALTER TABLE job_role_skills
  ADD CONSTRAINT jrs_tenant_fk FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE;
ALTER TABLE job_role_skills
  ADD CONSTRAINT jrs_skill_fk FOREIGN KEY (tenant_id, skill_id)
    REFERENCES skill_ontology(tenant_id, id) ON DELETE CASCADE;
ALTER TABLE job_role_skills
  ADD CONSTRAINT jrs_job_role_fk FOREIGN KEY (tenant_id, job_role_id)
    REFERENCES job_roles(tenant_id, id) ON DELETE CASCADE;

-- ═══════════════════════════════════════════════════════════════════
-- 3. EMPLOYEE_SKILLS — composite PK, CHECK constraints, new columns
-- ═══════════════════════════════════════════════════════════════════

-- Drop old FKs
ALTER TABLE employee_skills DROP CONSTRAINT IF EXISTS employee_skills_tenant_id_fkey;
ALTER TABLE employee_skills DROP CONSTRAINT IF EXISTS employee_skills_user_id_fkey;
ALTER TABLE employee_skills DROP CONSTRAINT IF EXISTS employee_skills_skill_id_fkey;

-- Drop old unique and PK
ALTER TABLE employee_skills DROP CONSTRAINT IF EXISTS employee_skills_user_id_skill_id_key;
ALTER TABLE employee_skills DROP CONSTRAINT IF EXISTS employee_skills_pkey;

-- Drop surrogate id
ALTER TABLE employee_skills DROP COLUMN IF EXISTS id;

-- Drop verified column
ALTER TABLE employee_skills DROP COLUMN IF EXISTS verified;

-- Add CHECK constraints on levels
ALTER TABLE employee_skills
  ALTER COLUMN self_assessed_level TYPE smallint;
ALTER TABLE employee_skills
  ADD CONSTRAINT es_self_level_chk CHECK (self_assessed_level BETWEEN 1 AND 5);

ALTER TABLE employee_skills
  ALTER COLUMN manager_assessed_level TYPE smallint;
ALTER TABLE employee_skills
  ADD CONSTRAINT es_mgr_level_chk CHECK (manager_assessed_level BETWEEN 1 AND 5);

-- New columns for assessment tracking
ALTER TABLE employee_skills ADD COLUMN IF NOT EXISTS self_assessed_at    timestamptz;
ALTER TABLE employee_skills ADD COLUMN IF NOT EXISTS manager_assessed_at timestamptz;
ALTER TABLE employee_skills ADD COLUMN IF NOT EXISTS manager_assessed_by uuid;

-- Backfill self_assessed_at for existing rows
UPDATE employee_skills SET self_assessed_at = created_at WHERE self_assessed_at IS NULL;
UPDATE employee_skills SET manager_assessed_at = updated_at
  WHERE manager_assessed_level IS NOT NULL AND manager_assessed_at IS NULL;

-- Composite PK
ALTER TABLE employee_skills ADD PRIMARY KEY (tenant_id, user_id, skill_id);

-- Composite FKs
ALTER TABLE employee_skills
  ADD CONSTRAINT es_tenant_fk FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE;
ALTER TABLE employee_skills
  ADD CONSTRAINT es_skill_fk FOREIGN KEY (tenant_id, skill_id)
    REFERENCES skill_ontology(tenant_id, id) ON DELETE CASCADE;
ALTER TABLE employee_skills
  ADD CONSTRAINT es_user_fk FOREIGN KEY (tenant_id, user_id)
    REFERENCES users(tenant_id, id) ON DELETE CASCADE;
ALTER TABLE employee_skills
  ADD CONSTRAINT es_manager_fk FOREIGN KEY (manager_assessed_by)
    REFERENCES users(id) ON DELETE SET NULL;

-- ═══════════════════════════════════════════════════════════════════
-- 4. Drop unused enums
-- ═══════════════════════════════════════════════════════════════════

DROP TYPE IF EXISTS "SkillImportance";
DROP TYPE IF EXISTS "SkillCategory";

-- ═══════════════════════════════════════════════════════════════════
-- 5. FORCE ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE skill_ontology  FORCE ROW LEVEL SECURITY;
ALTER TABLE job_role_skills  FORCE ROW LEVEL SECURITY;
ALTER TABLE employee_skills  FORCE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════
-- 6. DROP all old RLS policies
-- ═══════════════════════════════════════════════════════════════════

-- skill_ontology
DROP POLICY IF EXISTS "tenant_isolation"      ON skill_ontology;
DROP POLICY IF EXISTS "service_role_bypass"   ON skill_ontology;
DROP POLICY IF EXISTS "ontology_admin_write"  ON skill_ontology;
DROP POLICY IF EXISTS "ontology_admin_update" ON skill_ontology;
DROP POLICY IF EXISTS "ontology_admin_delete" ON skill_ontology;

-- job_role_skills
DROP POLICY IF EXISTS "tenant_isolation"    ON job_role_skills;
DROP POLICY IF EXISTS "service_role_bypass" ON job_role_skills;
DROP POLICY IF EXISTS "jrs_admin_write"     ON job_role_skills;
DROP POLICY IF EXISTS "jrs_admin_update"    ON job_role_skills;
DROP POLICY IF EXISTS "jrs_admin_delete"    ON job_role_skills;

-- employee_skills
DROP POLICY IF EXISTS "tenant_isolation"    ON employee_skills;
DROP POLICY IF EXISTS "service_role_bypass" ON employee_skills;
DROP POLICY IF EXISTS "es_user_visibility"  ON employee_skills;
DROP POLICY IF EXISTS "es_user_insert"      ON employee_skills;
DROP POLICY IF EXISTS "es_user_update"      ON employee_skills;

-- ═══════════════════════════════════════════════════════════════════
-- 7. NEW RLS policies
-- ═══════════════════════════════════════════════════════════════════

-- ─── skill_ontology ───────────────────────────────────────────────

CREATE POLICY so_select ON skill_ontology
  FOR SELECT TO authenticated
  USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY so_insert ON skill_ontology
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.requesting_tenant_id()
    AND public.is_tenant_admin()
  );

CREATE POLICY so_update ON skill_ontology
  FOR UPDATE TO authenticated
  USING (
    tenant_id = public.requesting_tenant_id()
    AND public.is_tenant_admin()
  );

-- ─── job_role_skills ──────────────────────────────────────────────

CREATE POLICY jrs_select ON job_role_skills
  FOR SELECT TO authenticated
  USING (tenant_id = public.requesting_tenant_id());

CREATE POLICY jrs_insert ON job_role_skills
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.requesting_tenant_id()
    AND public.is_tenant_admin()
  );

CREATE POLICY jrs_update ON job_role_skills
  FOR UPDATE TO authenticated
  USING (
    tenant_id = public.requesting_tenant_id()
    AND public.is_tenant_admin()
  );

-- ─── employee_skills ──────────────────────────────────────────────

CREATE POLICY es_select ON employee_skills
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.requesting_tenant_id()
    AND (
      user_id = (
        SELECT u.id FROM public.users u
        WHERE u.auth_uid = auth.uid()
          AND u.tenant_id = public.requesting_tenant_id()
        LIMIT 1
      )
      OR public.is_tenant_admin()
      OR EXISTS (
        SELECT 1 FROM public.ec_job_information eji
        WHERE eji.user_id = employee_skills.user_id
          AND eji.manager_id = (
            SELECT u.id FROM public.users u
            WHERE u.auth_uid = auth.uid()
              AND u.tenant_id = public.requesting_tenant_id()
            LIMIT 1
          )
          AND eji.tenant_id = public.requesting_tenant_id()
          AND eji.end_date IS NULL
      )
    )
  );

CREATE POLICY es_insert ON employee_skills
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.requesting_tenant_id()
    AND user_id = (
      SELECT u.id FROM public.users u
      WHERE u.auth_uid = auth.uid()
        AND u.tenant_id = public.requesting_tenant_id()
      LIMIT 1
    )
    AND manager_assessed_level IS NULL
    AND manager_assessed_at IS NULL
    AND manager_assessed_by IS NULL
  );

CREATE POLICY es_update ON employee_skills
  FOR UPDATE TO authenticated
  USING (
    tenant_id = public.requesting_tenant_id()
    AND user_id = (
      SELECT u.id FROM public.users u
      WHERE u.auth_uid = auth.uid()
        AND u.tenant_id = public.requesting_tenant_id()
      LIMIT 1
    )
  )
  WITH CHECK (
    tenant_id = public.requesting_tenant_id()
    AND user_id = (
      SELECT u.id FROM public.users u
      WHERE u.auth_uid = auth.uid()
        AND u.tenant_id = public.requesting_tenant_id()
      LIMIT 1
    )
  );

-- ═══════════════════════════════════════════════════════════════════
-- 8. COLUMN-LEVEL privileges on employee_skills
-- ═══════════════════════════════════════════════════════════════════

REVOKE UPDATE ON employee_skills FROM authenticated;
GRANT  UPDATE (self_assessed_level, self_assessed_at) ON employee_skills TO authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- 9. set_manager_assessment — SECURITY DEFINER function
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.set_manager_assessment(
  p_user_id  uuid,
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
  v_actor_id  uuid;
  v_old_level smallint;
BEGIN
  SELECT u.id, u.tenant_id INTO v_actor_id, v_tenant_id
  FROM public.users u
  WHERE u.auth_uid = auth.uid()
  LIMIT 1;

  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF p_level < 1 OR p_level > 5 THEN
    RAISE EXCEPTION 'Level must be between 1 and 5';
  END IF;

  IF NOT public.is_tenant_admin() THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.ec_job_information eji
      WHERE eji.user_id   = p_user_id
        AND eji.manager_id = v_actor_id
        AND eji.tenant_id  = v_tenant_id
        AND eji.end_date IS NULL
    ) THEN
      RAISE EXCEPTION 'Not authorized: not a direct manager or admin';
    END IF;
  END IF;

  SELECT es.manager_assessed_level INTO v_old_level
  FROM public.employee_skills es
  WHERE es.tenant_id = v_tenant_id
    AND es.user_id   = p_user_id
    AND es.skill_id  = p_skill_id;

  UPDATE public.employee_skills
  SET manager_assessed_level = p_level,
      manager_assessed_at    = now(),
      manager_assessed_by    = v_actor_id,
      updated_at             = now()
  WHERE tenant_id = v_tenant_id
    AND user_id   = p_user_id
    AND skill_id  = p_skill_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Employee skill record not found';
  END IF;

  PERFORM public.write_audit_log(
    v_tenant_id,
    v_actor_id,
    'tih.manager_assessment',
    'employee_skills',
    p_user_id::text || ':' || p_skill_id::text,
    jsonb_build_object('old_level', v_old_level, 'new_level', p_level)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_manager_assessment FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_manager_assessment FROM anon;
GRANT  EXECUTE ON FUNCTION public.set_manager_assessment TO authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- 10. GRANTS for prisma_app role
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT SELECT, INSERT, UPDATE ON skill_ontology  TO prisma_app;
    GRANT SELECT, INSERT, UPDATE ON job_role_skills  TO prisma_app;
    GRANT SELECT, INSERT         ON employee_skills  TO prisma_app;
    GRANT UPDATE (self_assessed_level, self_assessed_at) ON employee_skills TO prisma_app;
    GRANT EXECUTE ON FUNCTION public.set_manager_assessment TO prisma_app;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 11. RBP permission seeds for TIH
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_admin_role_id uuid;
  v_tenant_id     uuid;
BEGIN
  SELECT id INTO v_tenant_id FROM public.tenants WHERE slug = 'acme-corp' LIMIT 1;
  IF v_tenant_id IS NULL THEN RETURN; END IF;

  SELECT pr.id INTO v_admin_role_id
  FROM public.permission_roles pr
  WHERE pr.tenant_id = v_tenant_id AND pr.is_admin_role = true
  LIMIT 1;

  IF v_admin_role_id IS NULL THEN RETURN; END IF;

  INSERT INTO public.role_permissions (tenant_id, role_id, permission_name) VALUES
    (v_tenant_id, v_admin_role_id, 'tih.ontology.view'),
    (v_tenant_id, v_admin_role_id, 'tih.ontology.edit'),
    (v_tenant_id, v_admin_role_id, 'tih.job_requirements.view'),
    (v_tenant_id, v_admin_role_id, 'tih.job_requirements.edit'),
    (v_tenant_id, v_admin_role_id, 'tih.employee_skills.view'),
    (v_tenant_id, v_admin_role_id, 'tih.employee_skills.edit')
  ON CONFLICT (role_id, permission_name) DO NOTHING;
END $$;
