-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Loop 3 — Step 4: RBP Model v2                                     ║
-- ║  Evolves the Phase 6 RBP tables to match the refined permission     ║
-- ║  model: permission_key + field_key + action on role_permissions,    ║
-- ║  group_members for explicit membership, and role_grants with        ║
-- ║  enum-based target_population.                                      ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════
-- 1. ENUM: target_population_type
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  CREATE TYPE target_population_type AS ENUM (
    'all',
    'same_department',
    'direct_reports',
    'self'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE rbp_action AS ENUM ('view', 'edit');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 2. EVOLVE role_permissions: add permission_key, field_key, action
-- ═══════════════════════════════════════════════════════════════════

-- Make permission_name nullable (transitioning to permission_key)
ALTER TABLE role_permissions ALTER COLUMN permission_name DROP NOT NULL;

ALTER TABLE role_permissions
  ADD COLUMN IF NOT EXISTS permission_key text,
  ADD COLUMN IF NOT EXISTS field_key      text,
  ADD COLUMN IF NOT EXISTS action         rbp_action NOT NULL DEFAULT 'view';

-- Backfill: copy permission_name into permission_key where null
UPDATE role_permissions
SET permission_key = permission_name
WHERE permission_key IS NULL;

-- Drop old unique constraint and create new one
DO $$ BEGIN
  ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_role_id_permission_name_key;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

-- New unique: (role_id, permission_key, field_key, action)
DO $$ BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS idx_role_permissions_unique_v2
    ON role_permissions (role_id, permission_key, COALESCE(field_key, ''), action);
EXCEPTION WHEN duplicate_table THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_role_permissions_pkey_action
  ON role_permissions (permission_key, action);

-- ═══════════════════════════════════════════════════════════════════
-- 3. GROUP_MEMBERS: explicit user-to-group membership
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS group_members (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  group_id   uuid NOT NULL REFERENCES permission_groups(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_tenant ON group_members(tenant_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user   ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group  ON group_members(group_id);

ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members FORCE ROW LEVEL SECURITY;

CREATE POLICY "group_members_select" ON group_members
  FOR SELECT USING (tenant_id = requesting_tenant_id());

CREATE POLICY "group_members_insert" ON group_members
  FOR INSERT WITH CHECK (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "group_members_update" ON group_members
  FOR UPDATE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

-- ═══════════════════════════════════════════════════════════════════
-- 4. ROLE_GRANTS: role ↔ group with enum target_population
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS role_grants (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  role_id           uuid NOT NULL REFERENCES permission_roles(id) ON DELETE CASCADE,
  granted_group_id  uuid NOT NULL REFERENCES permission_groups(id) ON DELETE CASCADE,
  target_population target_population_type NOT NULL DEFAULT 'self',
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE(role_id, granted_group_id, target_population)
);

CREATE INDEX IF NOT EXISTS idx_role_grants_tenant ON role_grants(tenant_id);
CREATE INDEX IF NOT EXISTS idx_role_grants_role   ON role_grants(role_id);

ALTER TABLE role_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_grants FORCE ROW LEVEL SECURITY;

CREATE POLICY "role_grants_select" ON role_grants
  FOR SELECT USING (tenant_id = requesting_tenant_id());

CREATE POLICY "role_grants_insert" ON role_grants
  FOR INSERT WITH CHECK (tenant_id = requesting_tenant_id() AND is_tenant_admin());

CREATE POLICY "role_grants_update" ON role_grants
  FOR UPDATE USING (tenant_id = requesting_tenant_id() AND is_tenant_admin());

-- ═══════════════════════════════════════════════════════════════════
-- 5. GRANT access to prisma_app role
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN
  GRANT SELECT, INSERT, UPDATE ON group_members TO authenticated;
  GRANT SELECT, INSERT, UPDATE ON role_grants   TO authenticated;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prisma_app') THEN
    GRANT SELECT, INSERT, UPDATE ON group_members TO prisma_app;
    GRANT SELECT, INSERT, UPDATE ON role_grants   TO prisma_app;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 6. SEED: base roles (owner, hr_admin, manager, employee)
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_tenant_id uuid;
  v_owner_role uuid;
  v_hr_admin_role uuid;
  v_manager_role uuid;
  v_employee_role uuid;
  v_admins_group uuid;
  v_all_group uuid;
  v_managers_group uuid;
  v_elena_user uuid;
BEGIN
  SELECT id INTO v_tenant_id FROM tenants WHERE slug = 'acme-corp' LIMIT 1;
  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'No acme-corp tenant, skipping RBP v2 seed';
    RETURN;
  END IF;

  -- Owner role
  INSERT INTO permission_roles (id, tenant_id, name, description, is_admin_role)
  VALUES ('bb100000-0000-0000-0000-000000000010'::uuid, v_tenant_id, 'Owner', 'Tenant owner with full control', true)
  ON CONFLICT (tenant_id, name) DO NOTHING;
  v_owner_role := 'bb100000-0000-0000-0000-000000000010'::uuid;

  -- Reuse existing roles
  v_hr_admin_role := 'bb100000-0000-0000-0000-000000000001'::uuid;
  v_manager_role  := 'bb100000-0000-0000-0000-000000000003'::uuid;
  v_employee_role := 'bb100000-0000-0000-0000-000000000002'::uuid;
  v_admins_group  := 'cc100000-0000-0000-0000-000000000001'::uuid;
  v_all_group     := 'cc100000-0000-0000-0000-000000000002'::uuid;
  v_managers_group:= 'cc100000-0000-0000-0000-000000000003'::uuid;

  -- Owner permissions (permission_key + action + permission_name for compat)
  INSERT INTO role_permissions (tenant_id, role_id, permission_name, permission_key, action) VALUES
    (v_tenant_id, v_owner_role, 'admin.manage_roles',      'admin.manage_roles',       'edit'),
    (v_tenant_id, v_owner_role, 'admin.manage_config',     'admin.manage_config',      'edit'),
    (v_tenant_id, v_owner_role, 'admin.view_audit_logs',   'admin.view_audit_logs',    'view'),
    (v_tenant_id, v_owner_role, 'admin.manage_tenant',     'admin.manage_tenant',      'edit'),
    (v_tenant_id, v_owner_role, 'admin.manage_billing',    'admin.manage_billing',     'edit'),
    (v_tenant_id, v_owner_role, 'ec.manage_employees',     'ec.manage_employees',      'edit'),
    (v_tenant_id, v_owner_role, 'ec.manage_positions',     'ec.manage_positions',      'edit'),
    (v_tenant_id, v_owner_role, 'ec.manage_org_structure', 'ec.manage_org_structure',  'edit')
  ON CONFLICT DO NOTHING;

  -- Backfill existing role_permissions with action for existing rows
  UPDATE role_permissions
  SET permission_key = permission_name,
      action = CASE
        WHEN permission_name LIKE '%manage%' THEN 'edit'::rbp_action
        ELSE 'view'::rbp_action
      END
  WHERE permission_key IS NULL AND tenant_id = v_tenant_id;

  -- Role grants (enum target_population)
  INSERT INTO role_grants (tenant_id, role_id, granted_group_id, target_population) VALUES
    (v_tenant_id, v_owner_role,    v_admins_group,   'all'),
    (v_tenant_id, v_hr_admin_role, v_admins_group,   'all'),
    (v_tenant_id, v_manager_role,  v_managers_group,  'direct_reports'),
    (v_tenant_id, v_employee_role, v_all_group,       'self')
  ON CONFLICT (role_id, granted_group_id, target_population) DO NOTHING;

  -- Group members: add Elena as admin group member
  SELECT id INTO v_elena_user FROM users
  WHERE email = 'elena.martinez@acme.dev' AND tenant_id = v_tenant_id LIMIT 1;

  IF v_elena_user IS NOT NULL THEN
    INSERT INTO group_members (tenant_id, group_id, user_id)
    VALUES (v_tenant_id, v_admins_group, v_elena_user)
    ON CONFLICT (group_id, user_id) DO NOTHING;
  END IF;

END $$;
