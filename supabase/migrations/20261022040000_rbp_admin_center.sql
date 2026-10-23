-- ================================================================
-- Phase 6: Role-Based Permissions (RBP) + Admin Center
-- ================================================================

-- Helper function: checks if the current authenticated user
-- holds an admin role within their tenant.
CREATE OR REPLACE FUNCTION is_tenant_admin()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM role_assignments ra
    JOIN permission_roles pr ON pr.id = ra.role_id
    JOIN permission_groups pg ON pg.id = ra.granted_group_id
    WHERE pr.is_admin_role = true
      AND pr.tenant_id = requesting_tenant_id()
      AND pg.tenant_id = requesting_tenant_id()
      AND ra.tenant_id = requesting_tenant_id()
      AND EXISTS (
        SELECT 1 FROM users u
        WHERE u.auth_uid = auth.uid()
          AND u.tenant_id = requesting_tenant_id()
      )
  );
END;
$$;

-- ─── PERMISSION GROUPS ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS permission_groups (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  criteria_json jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_permission_groups_tenant ON permission_groups(tenant_id);

ALTER TABLE permission_groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "permission_groups_select" ON permission_groups
  FOR SELECT USING (tenant_id = requesting_tenant_id());

CREATE POLICY "permission_groups_insert" ON permission_groups
  FOR INSERT WITH CHECK (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "permission_groups_update" ON permission_groups
  FOR UPDATE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "permission_groups_delete" ON permission_groups
  FOR DELETE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

-- ─── PERMISSION ROLES ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS permission_roles (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  is_admin_role boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_permission_roles_tenant ON permission_roles(tenant_id);

ALTER TABLE permission_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "permission_roles_select" ON permission_roles
  FOR SELECT USING (tenant_id = requesting_tenant_id());

CREATE POLICY "permission_roles_insert" ON permission_roles
  FOR INSERT WITH CHECK (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "permission_roles_update" ON permission_roles
  FOR UPDATE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "permission_roles_delete" ON permission_roles
  FOR DELETE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

-- ─── ROLE PERMISSIONS ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS role_permissions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  role_id         uuid NOT NULL REFERENCES permission_roles(id) ON DELETE CASCADE,
  permission_name text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(role_id, permission_name)
);

CREATE INDEX IF NOT EXISTS idx_role_permissions_tenant ON role_permissions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);

ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "role_permissions_select" ON role_permissions
  FOR SELECT USING (tenant_id = requesting_tenant_id());

CREATE POLICY "role_permissions_insert" ON role_permissions
  FOR INSERT WITH CHECK (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "role_permissions_update" ON role_permissions
  FOR UPDATE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "role_permissions_delete" ON role_permissions
  FOR DELETE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

-- ─── ROLE ASSIGNMENTS ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS role_assignments (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                  uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  role_id                    uuid NOT NULL REFERENCES permission_roles(id) ON DELETE CASCADE,
  granted_group_id           uuid NOT NULL REFERENCES permission_groups(id) ON DELETE CASCADE,
  target_population_group_id uuid NOT NULL REFERENCES permission_groups(id) ON DELETE CASCADE,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_role_assignments_tenant ON role_assignments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_role_assignments_role ON role_assignments(role_id);

ALTER TABLE role_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "role_assignments_select" ON role_assignments
  FOR SELECT USING (tenant_id = requesting_tenant_id());

CREATE POLICY "role_assignments_insert" ON role_assignments
  FOR INSERT WITH CHECK (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "role_assignments_update" ON role_assignments
  FOR UPDATE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "role_assignments_delete" ON role_assignments
  FOR DELETE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

-- ─── SYSTEM CONFIGURATION ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS system_configurations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  key        text NOT NULL,
  value_json jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, key)
);

CREATE INDEX IF NOT EXISTS idx_system_configurations_tenant ON system_configurations(tenant_id);

ALTER TABLE system_configurations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "system_configurations_select" ON system_configurations
  FOR SELECT USING (tenant_id = requesting_tenant_id());

CREATE POLICY "system_configurations_insert" ON system_configurations
  FOR INSERT WITH CHECK (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "system_configurations_update" ON system_configurations
  FOR UPDATE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "system_configurations_delete" ON system_configurations
  FOR DELETE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

-- ─── AUDIT LOG (immutable — no UPDATE or DELETE policies) ─────────

CREATE TABLE IF NOT EXISTS audit_logs (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action       text NOT NULL,
  details_json jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant ON audit_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Admins can read audit logs; all authenticated users can insert (the system logs on their behalf)
CREATE POLICY "audit_logs_select" ON audit_logs
  FOR SELECT USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "audit_logs_insert" ON audit_logs
  FOR INSERT WITH CHECK (tenant_id = requesting_tenant_id());

-- No UPDATE or DELETE policies: audit logs are immutable

-- ─── SEED DATA: RBP bootstrap for demo tenant ────────────────────

DO $$
DECLARE
  v_tenant_id uuid;
  v_admin_role_id uuid;
  v_employee_role_id uuid;
  v_manager_role_id uuid;
  v_all_admins_group_id uuid;
  v_all_employees_group_id uuid;
  v_all_managers_group_id uuid;
BEGIN
  SELECT id INTO v_tenant_id FROM tenants WHERE slug = 'acme-corp' LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'No acme-corp tenant found, skipping RBP seed data';
    RETURN;
  END IF;

  -- Permission Roles
  INSERT INTO permission_roles (id, tenant_id, name, description, is_admin_role)
  VALUES
    ('bb100000-0000-0000-0000-000000000001'::uuid, v_tenant_id, 'HR Administrator', 'Full access to all HR modules and configuration', true),
    ('bb100000-0000-0000-0000-000000000002'::uuid, v_tenant_id, 'Employee (Self-Service)', 'View own profile, goals, and feedback', false),
    ('bb100000-0000-0000-0000-000000000003'::uuid, v_tenant_id, 'Manager', 'View and manage direct reports, approve requests', false)
  ON CONFLICT (tenant_id, name) DO NOTHING;

  v_admin_role_id    := 'bb100000-0000-0000-0000-000000000001'::uuid;
  v_employee_role_id := 'bb100000-0000-0000-0000-000000000002'::uuid;
  v_manager_role_id  := 'bb100000-0000-0000-0000-000000000003'::uuid;

  -- Permission Groups
  INSERT INTO permission_groups (id, tenant_id, name, description, criteria_json)
  VALUES
    ('cc100000-0000-0000-0000-000000000001'::uuid, v_tenant_id, 'All Administrators', 'Users with HR admin access', '{"match":"role","role":"HR Administrator"}'::jsonb),
    ('cc100000-0000-0000-0000-000000000002'::uuid, v_tenant_id, 'All Employees', 'Every active employee in the tenant', '{"match":"status","status":"ACTIVE"}'::jsonb),
    ('cc100000-0000-0000-0000-000000000003'::uuid, v_tenant_id, 'All Managers', 'Users occupying a position with direct reports', '{"match":"has_direct_reports","value":true}'::jsonb)
  ON CONFLICT (tenant_id, name) DO NOTHING;

  v_all_admins_group_id    := 'cc100000-0000-0000-0000-000000000001'::uuid;
  v_all_employees_group_id := 'cc100000-0000-0000-0000-000000000002'::uuid;
  v_all_managers_group_id  := 'cc100000-0000-0000-0000-000000000003'::uuid;

  -- Role Permissions (technical permissions per role)
  INSERT INTO role_permissions (tenant_id, role_id, permission_name) VALUES
    -- HR Admin: full access
    (v_tenant_id, v_admin_role_id, 'admin.manage_roles'),
    (v_tenant_id, v_admin_role_id, 'admin.manage_config'),
    (v_tenant_id, v_admin_role_id, 'admin.view_audit_logs'),
    (v_tenant_id, v_admin_role_id, 'ec.manage_positions'),
    (v_tenant_id, v_admin_role_id, 'ec.manage_employees'),
    (v_tenant_id, v_admin_role_id, 'ec.manage_org_structure'),
    (v_tenant_id, v_admin_role_id, 'pmgm.manage_goal_plans'),
    (v_tenant_id, v_admin_role_id, 'sdm.manage_succession'),
    -- Employee: self-service
    (v_tenant_id, v_employee_role_id, 'ec.view_own_profile'),
    (v_tenant_id, v_employee_role_id, 'ec.view_org_chart'),
    (v_tenant_id, v_employee_role_id, 'pmgm.view_own_goals'),
    (v_tenant_id, v_employee_role_id, 'pmgm.give_feedback'),
    -- Manager: team management
    (v_tenant_id, v_manager_role_id, 'ec.view_team_profiles'),
    (v_tenant_id, v_manager_role_id, 'pmgm.manage_team_goals'),
    (v_tenant_id, v_manager_role_id, 'pmgm.view_team_feedback'),
    (v_tenant_id, v_manager_role_id, 'sdm.nominate_successors')
  ON CONFLICT (role_id, permission_name) DO NOTHING;

  -- Role Assignments (who gets what role over which population)
  INSERT INTO role_assignments (tenant_id, role_id, granted_group_id, target_population_group_id) VALUES
    (v_tenant_id, v_admin_role_id,    v_all_admins_group_id,    v_all_employees_group_id),
    (v_tenant_id, v_employee_role_id, v_all_employees_group_id, v_all_employees_group_id),
    (v_tenant_id, v_manager_role_id,  v_all_managers_group_id,  v_all_employees_group_id);

  -- System Configurations (tenant-level settings)
  INSERT INTO system_configurations (tenant_id, key, value_json) VALUES
    (v_tenant_id, 'platform.locale', '"es"'::jsonb),
    (v_tenant_id, 'platform.timezone', '"America/Mexico_City"'::jsonb),
    (v_tenant_id, 'security.password_policy', '{"min_length":8,"require_uppercase":true,"require_number":true,"require_special":false,"max_age_days":90}'::jsonb),
    (v_tenant_id, 'security.session_timeout_minutes', '30'::jsonb),
    (v_tenant_id, 'modules.active', '["ec","pmgm","sdm","rbp"]'::jsonb)
  ON CONFLICT (tenant_id, key) DO NOTHING;

  -- Audit Log: record the RBP bootstrap
  INSERT INTO audit_logs (tenant_id, user_id, action, details_json)
  SELECT v_tenant_id, u.id, 'SYSTEM_BOOTSTRAP_RBP', '{"phase":6,"description":"Initial RBP seed data created"}'::jsonb
  FROM users u
  WHERE u.tenant_id = v_tenant_id AND u.email = 'elena.martinez@acme.dev'
  LIMIT 1;

END $$;
