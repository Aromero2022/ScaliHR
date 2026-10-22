-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  MIGRATION: ec_position_and_foundation                             ║
-- ║  Position Management, Foundation Objects (Job Profile Builder),    ║
-- ║  MDF Object Definitions, and Business Rules Engine                 ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ─── 1. FOUNDATION OBJECTS ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.job_families (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  family_code text NOT NULL,
  name        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, family_code)
);
CREATE INDEX idx_job_families_tenant ON public.job_families(tenant_id);

CREATE TABLE IF NOT EXISTS public.job_roles (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  role_code     text NOT NULL,
  name          text NOT NULL,
  job_family_id uuid NOT NULL REFERENCES public.job_families(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, role_code)
);
CREATE INDEX idx_job_roles_tenant ON public.job_roles(tenant_id);
CREATE INDEX idx_job_roles_family ON public.job_roles(job_family_id);

CREATE TABLE IF NOT EXISTS public.job_classifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  job_code    text NOT NULL,
  title       text NOT NULL,
  pay_grade   text,
  job_role_id uuid NOT NULL REFERENCES public.job_roles(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, job_code)
);
CREATE INDEX idx_job_classifications_tenant ON public.job_classifications(tenant_id);
CREATE INDEX idx_job_classifications_role ON public.job_classifications(job_role_id);

-- ─── 2. POSITION MANAGEMENT ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.positions (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  position_code         text NOT NULL,
  title                 text NOT NULL,
  fte                   double precision NOT NULL DEFAULT 1.0,
  is_vacant             boolean NOT NULL DEFAULT true,
  department_id         uuid REFERENCES public.departments(id),
  job_classification_id uuid REFERENCES public.job_classifications(id),
  parent_position_id    uuid REFERENCES public.positions(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, position_code)
);
CREATE INDEX idx_positions_tenant ON public.positions(tenant_id);
CREATE INDEX idx_positions_parent ON public.positions(parent_position_id);
CREATE INDEX idx_positions_department ON public.positions(department_id);

-- ─── 3. REFACTOR JOB_INFORMATIONS: add position + classification links ─

ALTER TABLE public.job_informations
  ADD COLUMN IF NOT EXISTS position_id uuid REFERENCES public.positions(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS job_classification_id uuid REFERENCES public.job_classifications(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_job_informations_position ON public.job_informations(position_id);

-- Drop legacy columns that are now modeled by the foundation chain
ALTER TABLE public.job_informations
  DROP COLUMN IF EXISTS job_code,
  DROP COLUMN IF EXISTS job_family;

-- ─── 4. REFACTOR USERS: manager_id → position_id ───────────────────

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS position_id uuid REFERENCES public.positions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_users_position ON public.users(position_id);

-- Remove direct manager hierarchy (now via Position.parent_position_id)
ALTER TABLE public.users DROP COLUMN IF EXISTS manager_id;

-- ─── 5. MDF: OBJECT DEFINITIONS ────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.object_definitions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code        text NOT NULL,
  label       text NOT NULL,
  schema_json jsonb NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);
CREATE INDEX idx_object_definitions_tenant ON public.object_definitions(tenant_id);

-- ─── 6. BUSINESS RULES ENGINE ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.business_rules (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id              uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  rule_id                text NOT NULL,
  base_object            text NOT NULL,
  trigger_event          text NOT NULL,
  conditions_actions_json jsonb NOT NULL DEFAULT '{}',
  status                 boolean NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, rule_id)
);
CREATE INDEX idx_business_rules_tenant ON public.business_rules(tenant_id);
CREATE INDEX idx_business_rules_base_object ON public.business_rules(base_object);

-- ═══════════════════════════════════════════════════════════════════
-- RLS POLICIES FOR ALL 6 NEW TABLES
-- ═══════════════════════════════════════════════════════════════════

-- ─── JOB FAMILIES ───────────────────────────────────────────────────

ALTER TABLE public.job_families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_families FORCE ROW LEVEL SECURITY;

CREATE POLICY job_families_tenant_select ON public.job_families
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY job_families_tenant_insert ON public.job_families
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());
CREATE POLICY job_families_tenant_update ON public.job_families
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY job_families_tenant_delete ON public.job_families
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── JOB ROLES ──────────────────────────────────────────────────────

ALTER TABLE public.job_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_roles FORCE ROW LEVEL SECURITY;

CREATE POLICY job_roles_tenant_select ON public.job_roles
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY job_roles_tenant_insert ON public.job_roles
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());
CREATE POLICY job_roles_tenant_update ON public.job_roles
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY job_roles_tenant_delete ON public.job_roles
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── JOB CLASSIFICATIONS ────────────────────────────────────────────

ALTER TABLE public.job_classifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_classifications FORCE ROW LEVEL SECURITY;

CREATE POLICY job_classifications_tenant_select ON public.job_classifications
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY job_classifications_tenant_insert ON public.job_classifications
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());
CREATE POLICY job_classifications_tenant_update ON public.job_classifications
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY job_classifications_tenant_delete ON public.job_classifications
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── POSITIONS ──────────────────────────────────────────────────────

ALTER TABLE public.positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.positions FORCE ROW LEVEL SECURITY;

CREATE POLICY positions_tenant_select ON public.positions
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY positions_tenant_insert ON public.positions
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());
CREATE POLICY positions_tenant_update ON public.positions
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY positions_tenant_delete ON public.positions
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── OBJECT DEFINITIONS ────────────────────────────────────────────

ALTER TABLE public.object_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.object_definitions FORCE ROW LEVEL SECURITY;

CREATE POLICY object_definitions_tenant_select ON public.object_definitions
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY object_definitions_tenant_insert ON public.object_definitions
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());
CREATE POLICY object_definitions_tenant_update ON public.object_definitions
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY object_definitions_tenant_delete ON public.object_definitions
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ─── BUSINESS RULES ────────────────────────────────────────────────

ALTER TABLE public.business_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_rules FORCE ROW LEVEL SECURITY;

CREATE POLICY business_rules_tenant_select ON public.business_rules
  FOR SELECT USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY business_rules_tenant_insert ON public.business_rules
  FOR INSERT WITH CHECK (tenant_id = public.requesting_tenant_id());
CREATE POLICY business_rules_tenant_update ON public.business_rules
  FOR UPDATE USING (tenant_id = public.requesting_tenant_id());
CREATE POLICY business_rules_tenant_delete ON public.business_rules
  FOR DELETE USING (tenant_id = public.requesting_tenant_id());

-- ═══════════════════════════════════════════════════════════════════
-- SEED DATA: Foundation Objects & Positions for demo tenant
-- ═══════════════════════════════════════════════════════════════════

-- Job Families
INSERT INTO public.job_families (id, tenant_id, family_code, name) VALUES
  ('f1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'EXEC', 'Executive Leadership'),
  ('f1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'ENG', 'Engineering'),
  ('f1000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'SALES', 'Sales & Marketing'),
  ('f1000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'HR', 'Human Resources')
ON CONFLICT (tenant_id, family_code) DO NOTHING;

-- Job Roles
INSERT INTO public.job_roles (id, tenant_id, role_code, name, job_family_id) VALUES
  ('aa100000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'CEO', 'Chief Executive Officer', 'f1000000-0000-0000-0000-000000000001'),
  ('aa100000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'CTO', 'Chief Technology Officer', 'f1000000-0000-0000-0000-000000000001'),
  ('aa100000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'VP_SALES', 'VP of Sales', 'f1000000-0000-0000-0000-000000000001'),
  ('aa100000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'HR_DIR', 'HR Director', 'f1000000-0000-0000-0000-000000000004'),
  ('aa100000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'LEAD_FE', 'Frontend Lead', 'f1000000-0000-0000-0000-000000000002'),
  ('aa100000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'LEAD_BE', 'Backend Lead', 'f1000000-0000-0000-0000-000000000002'),
  ('aa100000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', 'SWE', 'Software Engineer', 'f1000000-0000-0000-0000-000000000002'),
  ('aa100000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'SALES_MGR', 'Sales Manager', 'f1000000-0000-0000-0000-000000000003'),
  ('aa100000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'HR_SPEC', 'HR Specialist', 'f1000000-0000-0000-0000-000000000004')
ON CONFLICT (tenant_id, role_code) DO NOTHING;

-- Job Classifications
INSERT INTO public.job_classifications (id, tenant_id, job_code, title, pay_grade, job_role_id) VALUES
  ('cc100000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'CEO-L1', 'CEO', 'EX-1', 'aa100000-0000-0000-0000-000000000001'),
  ('cc100000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'CTO-L1', 'CTO', 'EX-2', 'aa100000-0000-0000-0000-000000000002'),
  ('cc100000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'VP-SALES-L1', 'VP of Sales', 'EX-2', 'aa100000-0000-0000-0000-000000000003'),
  ('cc100000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'HR-DIR-L1', 'HR Director', 'M-1', 'aa100000-0000-0000-0000-000000000004'),
  ('cc100000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'FE-LEAD-L1', 'Frontend Lead', 'M-2', 'aa100000-0000-0000-0000-000000000005'),
  ('cc100000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'BE-LEAD-L1', 'Backend Lead', 'M-2', 'aa100000-0000-0000-0000-000000000006'),
  ('cc100000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', 'SWE-L1', 'Software Engineer', 'IC-3', 'aa100000-0000-0000-0000-000000000007'),
  ('cc100000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'SALES-MGR-L1', 'Sales Manager', 'M-2', 'aa100000-0000-0000-0000-000000000008'),
  ('cc100000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'HR-SPEC-L1', 'HR Specialist', 'IC-2', 'aa100000-0000-0000-0000-000000000009')
ON CONFLICT (tenant_id, job_code) DO NOTHING;

-- Positions (hierarchy via parent_position_id)
INSERT INTO public.positions (id, tenant_id, position_code, title, fte, is_vacant, department_id, job_classification_id, parent_position_id) VALUES
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'POS-001', 'CEO', 1.0, false, 'd0000000-0000-0000-0000-000000000001', 'cc100000-0000-0000-0000-000000000001', NULL),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'POS-002', 'CTO', 1.0, false, 'd0000000-0000-0000-0000-000000000002', 'cc100000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001'),
  ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'POS-003', 'VP of Sales', 1.0, false, 'd0000000-0000-0000-0000-000000000003', 'cc100000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001'),
  ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'POS-004', 'HR Director', 1.0, false, 'd0000000-0000-0000-0000-000000000004', 'cc100000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001'),
  ('b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'POS-005', 'Frontend Lead', 1.0, false, 'd0000000-0000-0000-0000-000000000005', 'cc100000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000002'),
  ('b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'POS-006', 'Backend Lead', 1.0, false, 'd0000000-0000-0000-0000-000000000006', 'cc100000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000002'),
  ('b0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', 'POS-007', 'Sales Manager', 1.0, true, 'd0000000-0000-0000-0000-000000000003', 'cc100000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000003'),
  ('b0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'POS-008', 'HR Specialist', 1.0, false, 'd0000000-0000-0000-0000-000000000004', 'cc100000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000004'),
  ('b0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'POS-009', 'Frontend Engineer', 1.0, false, 'd0000000-0000-0000-0000-000000000005', 'cc100000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000005'),
  ('b0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000001', 'POS-010', 'Backend Engineer', 1.0, false, 'd0000000-0000-0000-0000-000000000006', 'cc100000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000006'),
  ('b0000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000001', 'POS-011', 'Sales Executive', 1.0, false, 'd0000000-0000-0000-0000-000000000003', 'cc100000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000007'),
  ('b0000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000001', 'POS-012', 'Senior Frontend Engineer', 1.0, true, 'd0000000-0000-0000-0000-000000000005', 'cc100000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000005'),
  ('b0000000-0000-0000-0000-000000000013', 'a0000000-0000-0000-0000-000000000001', 'POS-013', 'DevOps Engineer', 1.0, true, 'd0000000-0000-0000-0000-000000000006', 'cc100000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000006')
ON CONFLICT (tenant_id, position_code) DO NOTHING;

-- Link users to their positions
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000001' WHERE id = 'e0000000-0000-0000-0000-000000000001';
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000002' WHERE id = 'e0000000-0000-0000-0000-000000000002';
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000003' WHERE id = 'e0000000-0000-0000-0000-000000000003';
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000004' WHERE id = 'e0000000-0000-0000-0000-000000000004';
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000005' WHERE id = 'e0000000-0000-0000-0000-000000000005';
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000006' WHERE id = 'e0000000-0000-0000-0000-000000000006';
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000009' WHERE id = 'e0000000-0000-0000-0000-000000000007';
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000010' WHERE id = 'e0000000-0000-0000-0000-000000000008';
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000011' WHERE id = 'e0000000-0000-0000-0000-000000000009';
UPDATE public.users SET position_id = 'b0000000-0000-0000-0000-000000000008' WHERE id = 'e0000000-0000-0000-0000-000000000010';
