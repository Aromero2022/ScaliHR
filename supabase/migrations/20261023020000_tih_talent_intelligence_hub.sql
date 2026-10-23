-- ================================================================
-- Phase 8: TIH — Talent Intelligence Hub
-- ================================================================
-- Models: SkillOntology, JobRoleSkill, EmployeeSkill
-- RLS: Ontology + JobRoleSkill read-only for authenticated,
--       admin-only write. EmployeeSkill allows user self-assessment.
-- RESTRICTIVE policies layered on permissive tenant_isolation.
-- ================================================================

-- ─── ENUMS ─────────────────────────────────────────────────────────

DO $$ BEGIN
  CREATE TYPE "SkillCategory" AS ENUM ('TECHNICAL','LEADERSHIP','FUNCTIONAL','INTERPERSONAL','LANGUAGE','CERTIFICATION');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "SkillImportance" AS ENUM ('CRITICAL','REQUIRED','PREFERRED','NICE_TO_HAVE');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─── TABLES ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS skill_ontology (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  code        text NOT NULL,
  name        text NOT NULL,
  description text,
  category    "SkillCategory" NOT NULL DEFAULT 'TECHNICAL',
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, code)
);
CREATE INDEX IF NOT EXISTS idx_skill_ontology_tenant ON skill_ontology(tenant_id);
CREATE INDEX IF NOT EXISTS idx_skill_ontology_category ON skill_ontology(category);

CREATE TABLE IF NOT EXISTS job_role_skills (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  job_role_id     uuid NOT NULL REFERENCES job_roles(id) ON DELETE CASCADE,
  skill_id        uuid NOT NULL REFERENCES skill_ontology(id) ON DELETE CASCADE,
  required_level  int NOT NULL DEFAULT 3,
  importance      "SkillImportance" NOT NULL DEFAULT 'REQUIRED',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(job_role_id, skill_id)
);
CREATE INDEX IF NOT EXISTS idx_job_role_skills_tenant ON job_role_skills(tenant_id);
CREATE INDEX IF NOT EXISTS idx_job_role_skills_role ON job_role_skills(job_role_id);
CREATE INDEX IF NOT EXISTS idx_job_role_skills_skill ON job_role_skills(skill_id);

CREATE TABLE IF NOT EXISTS employee_skills (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  user_id                 uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  skill_id                uuid NOT NULL REFERENCES skill_ontology(id) ON DELETE CASCADE,
  self_assessed_level     int NOT NULL DEFAULT 1,
  manager_assessed_level  int,
  verified                boolean NOT NULL DEFAULT false,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, skill_id)
);
CREATE INDEX IF NOT EXISTS idx_employee_skills_tenant ON employee_skills(tenant_id);
CREATE INDEX IF NOT EXISTS idx_employee_skills_user ON employee_skills(user_id);
CREATE INDEX IF NOT EXISTS idx_employee_skills_skill ON employee_skills(skill_id);

-- ─── ENABLE RLS ────────────────────────────────────────────────────

ALTER TABLE skill_ontology ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_role_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_skills ENABLE ROW LEVEL SECURITY;

-- ─── PERMISSIVE: tenant isolation + service_role bypass ────────────

CREATE POLICY "tenant_isolation" ON skill_ontology
  FOR ALL TO authenticated
  USING (tenant_id = requesting_tenant_id())
  WITH CHECK (tenant_id = requesting_tenant_id());

CREATE POLICY "service_role_bypass" ON skill_ontology
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "tenant_isolation" ON job_role_skills
  FOR ALL TO authenticated
  USING (tenant_id = requesting_tenant_id())
  WITH CHECK (tenant_id = requesting_tenant_id());

CREATE POLICY "service_role_bypass" ON job_role_skills
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "tenant_isolation" ON employee_skills
  FOR ALL TO authenticated
  USING (tenant_id = requesting_tenant_id())
  WITH CHECK (tenant_id = requesting_tenant_id());

CREATE POLICY "service_role_bypass" ON employee_skills
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ─── RESTRICTIVE: ontology admin-only write ────────────────────────

CREATE POLICY "ontology_admin_write" ON skill_ontology
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (is_tenant_admin());

CREATE POLICY "ontology_admin_update" ON skill_ontology
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (is_tenant_admin());

CREATE POLICY "ontology_admin_delete" ON skill_ontology
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (is_tenant_admin());

-- ─── RESTRICTIVE: job_role_skills admin-only write ─────────────────

CREATE POLICY "jrs_admin_write" ON job_role_skills
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (is_tenant_admin());

CREATE POLICY "jrs_admin_update" ON job_role_skills
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (is_tenant_admin());

CREATE POLICY "jrs_admin_delete" ON job_role_skills
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (is_tenant_admin());

-- ─── RESTRICTIVE: employee_skills user-level access ────────────────

CREATE POLICY "es_user_visibility" ON employee_skills
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    user_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
    OR is_tenant_admin()
  );

CREATE POLICY "es_user_insert" ON employee_skills
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
  );

CREATE POLICY "es_user_update" ON employee_skills
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT id FROM users WHERE auth_uid = auth.uid() AND tenant_id = requesting_tenant_id() LIMIT 1)
    OR is_tenant_admin()
  );

-- ─── TENANT FLAG ───────────────────────────────────────────────────

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS is_tih_active boolean NOT NULL DEFAULT false;

-- ─── SEED DATA ─────────────────────────────────────────────────────

DO $$
DECLARE
  v_tenant_id uuid;
  v_elena_id uuid;
  v_carlos_id uuid;
  v_marcus_id uuid;
  v_jr_hr_mgr uuid;
  v_jr_sw_eng uuid;
  v_sk_leadership uuid;
  v_sk_communication uuid;
  v_sk_javascript uuid;
  v_sk_typescript uuid;
  v_sk_react uuid;
  v_sk_nodejs uuid;
  v_sk_sql uuid;
  v_sk_python uuid;
  v_sk_recruiting uuid;
  v_sk_labor_law uuid;
  v_sk_onboarding uuid;
  v_sk_conflict uuid;
BEGIN
  SELECT id INTO v_tenant_id FROM tenants WHERE slug = 'acme-corp' LIMIT 1;
  IF v_tenant_id IS NULL THEN RETURN; END IF;

  UPDATE tenants SET is_tih_active = true WHERE id = v_tenant_id;

  SELECT id INTO v_elena_id FROM users WHERE email = 'elena.martinez@acme.dev' AND tenant_id = v_tenant_id LIMIT 1;
  SELECT id INTO v_carlos_id FROM users WHERE email = 'carlos.reyes@acme.dev' AND tenant_id = v_tenant_id LIMIT 1;
  SELECT id INTO v_marcus_id FROM users WHERE email = 'marcus.johnson@acme.dev' AND tenant_id = v_tenant_id LIMIT 1;

  IF v_elena_id IS NULL THEN RETURN; END IF;

  -- Skill Ontology
  INSERT INTO skill_ontology (id, tenant_id, code, name, description, category) VALUES
    (gen_random_uuid(), v_tenant_id, 'LEADERSHIP', 'Liderazgo', 'Capacidad de guiar equipos y tomar decisiones estratégicas', 'LEADERSHIP'),
    (gen_random_uuid(), v_tenant_id, 'COMMUNICATION', 'Comunicación Efectiva', 'Habilidad para transmitir ideas de forma clara y persuasiva', 'INTERPERSONAL'),
    (gen_random_uuid(), v_tenant_id, 'JAVASCRIPT', 'JavaScript', 'Desarrollo con JavaScript ES6+, DOM, APIs del navegador', 'TECHNICAL'),
    (gen_random_uuid(), v_tenant_id, 'TYPESCRIPT', 'TypeScript', 'Tipado estático, interfaces, generics y patrones avanzados', 'TECHNICAL'),
    (gen_random_uuid(), v_tenant_id, 'REACT', 'React', 'Desarrollo de interfaces con React, hooks, estado y rendimiento', 'TECHNICAL'),
    (gen_random_uuid(), v_tenant_id, 'NODEJS', 'Node.js', 'Backend con Node.js, Express, APIs REST y microservicios', 'TECHNICAL'),
    (gen_random_uuid(), v_tenant_id, 'SQL_DB', 'SQL y Bases de Datos', 'Modelado relacional, queries avanzados, optimización', 'TECHNICAL'),
    (gen_random_uuid(), v_tenant_id, 'PYTHON', 'Python', 'Desarrollo con Python, automatización, scripting', 'TECHNICAL'),
    (gen_random_uuid(), v_tenant_id, 'RECRUITING', 'Reclutamiento y Selección', 'Sourcing, entrevistas, assessment centers, employer branding', 'FUNCTIONAL'),
    (gen_random_uuid(), v_tenant_id, 'LABOR_LAW', 'Legislación Laboral', 'Normativa laboral, contratos, compliance regulatorio', 'FUNCTIONAL'),
    (gen_random_uuid(), v_tenant_id, 'ONBOARDING', 'Diseño de Onboarding', 'Programas de incorporación, integración cultural, métricas de adaptación', 'FUNCTIONAL'),
    (gen_random_uuid(), v_tenant_id, 'CONFLICT_RES', 'Resolución de Conflictos', 'Mediación, negociación, gestión de dinámicas interpersonales', 'INTERPERSONAL')
  ON CONFLICT (tenant_id, code) DO NOTHING;

  -- Fetch skill IDs
  SELECT id INTO v_sk_leadership FROM skill_ontology WHERE code = 'LEADERSHIP' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_communication FROM skill_ontology WHERE code = 'COMMUNICATION' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_javascript FROM skill_ontology WHERE code = 'JAVASCRIPT' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_typescript FROM skill_ontology WHERE code = 'TYPESCRIPT' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_react FROM skill_ontology WHERE code = 'REACT' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_nodejs FROM skill_ontology WHERE code = 'NODEJS' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_sql FROM skill_ontology WHERE code = 'SQL_DB' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_python FROM skill_ontology WHERE code = 'PYTHON' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_recruiting FROM skill_ontology WHERE code = 'RECRUITING' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_labor_law FROM skill_ontology WHERE code = 'LABOR_LAW' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_onboarding FROM skill_ontology WHERE code = 'ONBOARDING' AND tenant_id = v_tenant_id;
  SELECT id INTO v_sk_conflict FROM skill_ontology WHERE code = 'CONFLICT_RES' AND tenant_id = v_tenant_id;

  -- JobRole lookups
  SELECT id INTO v_jr_hr_mgr FROM job_roles WHERE role_code = 'HR_DIR' AND tenant_id = v_tenant_id LIMIT 1;
  SELECT id INTO v_jr_sw_eng FROM job_roles WHERE role_code = 'SWE' AND tenant_id = v_tenant_id LIMIT 1;

  -- JobRoleSkill mappings: HR Director
  IF v_jr_hr_mgr IS NOT NULL THEN
    INSERT INTO job_role_skills (tenant_id, job_role_id, skill_id, required_level, importance) VALUES
      (v_tenant_id, v_jr_hr_mgr, v_sk_leadership, 4, 'CRITICAL'),
      (v_tenant_id, v_jr_hr_mgr, v_sk_communication, 4, 'CRITICAL'),
      (v_tenant_id, v_jr_hr_mgr, v_sk_recruiting, 5, 'CRITICAL'),
      (v_tenant_id, v_jr_hr_mgr, v_sk_labor_law, 4, 'REQUIRED'),
      (v_tenant_id, v_jr_hr_mgr, v_sk_onboarding, 4, 'REQUIRED'),
      (v_tenant_id, v_jr_hr_mgr, v_sk_conflict, 3, 'PREFERRED')
    ON CONFLICT (job_role_id, skill_id) DO NOTHING;
  END IF;

  -- JobRoleSkill mappings: Software Engineer
  IF v_jr_sw_eng IS NOT NULL THEN
    INSERT INTO job_role_skills (tenant_id, job_role_id, skill_id, required_level, importance) VALUES
      (v_tenant_id, v_jr_sw_eng, v_sk_javascript, 4, 'CRITICAL'),
      (v_tenant_id, v_jr_sw_eng, v_sk_typescript, 4, 'CRITICAL'),
      (v_tenant_id, v_jr_sw_eng, v_sk_react, 4, 'REQUIRED'),
      (v_tenant_id, v_jr_sw_eng, v_sk_nodejs, 3, 'REQUIRED'),
      (v_tenant_id, v_jr_sw_eng, v_sk_sql, 3, 'REQUIRED'),
      (v_tenant_id, v_jr_sw_eng, v_sk_python, 2, 'PREFERRED'),
      (v_tenant_id, v_jr_sw_eng, v_sk_communication, 3, 'PREFERRED')
    ON CONFLICT (job_role_id, skill_id) DO NOTHING;
  END IF;

  -- EmployeeSkill self-assessments: Elena (HR Manager)
  INSERT INTO employee_skills (tenant_id, user_id, skill_id, self_assessed_level, manager_assessed_level, verified) VALUES
    (v_tenant_id, v_elena_id, v_sk_leadership, 4, 4, true),
    (v_tenant_id, v_elena_id, v_sk_communication, 5, 4, true),
    (v_tenant_id, v_elena_id, v_sk_recruiting, 5, 5, true),
    (v_tenant_id, v_elena_id, v_sk_labor_law, 3, 3, true),
    (v_tenant_id, v_elena_id, v_sk_onboarding, 4, NULL, false),
    (v_tenant_id, v_elena_id, v_sk_conflict, 4, NULL, false)
  ON CONFLICT (user_id, skill_id) DO NOTHING;

  -- EmployeeSkill self-assessments: Carlos (Software Engineer)
  IF v_carlos_id IS NOT NULL THEN
    INSERT INTO employee_skills (tenant_id, user_id, skill_id, self_assessed_level, manager_assessed_level, verified) VALUES
      (v_tenant_id, v_carlos_id, v_sk_javascript, 5, 5, true),
      (v_tenant_id, v_carlos_id, v_sk_typescript, 4, 4, true),
      (v_tenant_id, v_carlos_id, v_sk_react, 4, 4, true),
      (v_tenant_id, v_carlos_id, v_sk_nodejs, 4, 3, true),
      (v_tenant_id, v_carlos_id, v_sk_sql, 3, 3, false),
      (v_tenant_id, v_carlos_id, v_sk_python, 2, NULL, false),
      (v_tenant_id, v_carlos_id, v_sk_leadership, 3, NULL, false)
    ON CONFLICT (user_id, skill_id) DO NOTHING;
  END IF;

  -- EmployeeSkill self-assessments: Marcus
  IF v_marcus_id IS NOT NULL THEN
    INSERT INTO employee_skills (tenant_id, user_id, skill_id, self_assessed_level) VALUES
      (v_tenant_id, v_marcus_id, v_sk_communication, 4),
      (v_tenant_id, v_marcus_id, v_sk_leadership, 2),
      (v_tenant_id, v_marcus_id, v_sk_conflict, 3)
    ON CONFLICT (user_id, skill_id) DO NOTHING;
  END IF;
END $$;
