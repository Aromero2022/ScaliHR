-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  RBP Seeds for TIH — permission groups, roles, and assignments     ║
-- ║  for all standard roles: employee, manager, hr_admin, owner        ║
-- ╚══════════════════════════════════════════════════════════════════════╝

DO $$
DECLARE
  v_tenant_id uuid;
  -- Permission groups
  v_pg_all       uuid;
  v_pg_self      uuid;
  v_pg_direct    uuid;
  -- Permission roles
  v_role_employee  uuid;
  v_role_manager   uuid;
  v_role_hr_admin  uuid;
  v_role_admin     uuid;
BEGIN
  SELECT id INTO v_tenant_id FROM public.tenants WHERE slug = 'acme-corp' LIMIT 1;
  IF v_tenant_id IS NULL THEN RETURN; END IF;

  -- ─── Permission Groups (dynamic membership via criteria_json) ──────

  INSERT INTO public.permission_groups (id, tenant_id, name, criteria_json)
  VALUES (gen_random_uuid(), v_tenant_id, 'All Employees', '{"type": "all"}'::jsonb)
  ON CONFLICT (tenant_id, name) DO NOTHING
  RETURNING id INTO v_pg_all;
  IF v_pg_all IS NULL THEN
    SELECT id INTO v_pg_all FROM public.permission_groups
    WHERE tenant_id = v_tenant_id AND name = 'All Employees';
  END IF;

  INSERT INTO public.permission_groups (id, tenant_id, name, criteria_json)
  VALUES (gen_random_uuid(), v_tenant_id, 'Self Only', '{"type": "self"}'::jsonb)
  ON CONFLICT (tenant_id, name) DO NOTHING
  RETURNING id INTO v_pg_self;
  IF v_pg_self IS NULL THEN
    SELECT id INTO v_pg_self FROM public.permission_groups
    WHERE tenant_id = v_tenant_id AND name = 'Self Only';
  END IF;

  INSERT INTO public.permission_groups (id, tenant_id, name, criteria_json)
  VALUES (gen_random_uuid(), v_tenant_id, 'Direct Reports', '{"type": "direct_reports"}'::jsonb)
  ON CONFLICT (tenant_id, name) DO NOTHING
  RETURNING id INTO v_pg_direct;
  IF v_pg_direct IS NULL THEN
    SELECT id INTO v_pg_direct FROM public.permission_groups
    WHERE tenant_id = v_tenant_id AND name = 'Direct Reports';
  END IF;

  -- ─── Permission Roles ─────────────────────────────────────────────

  INSERT INTO public.permission_roles (id, tenant_id, name, description, is_admin_role)
  VALUES (gen_random_uuid(), v_tenant_id, 'TIH Employee', 'Self-assessment on own skills', false)
  ON CONFLICT (tenant_id, name) DO NOTHING
  RETURNING id INTO v_role_employee;
  IF v_role_employee IS NULL THEN
    SELECT id INTO v_role_employee FROM public.permission_roles
    WHERE tenant_id = v_tenant_id AND name = 'TIH Employee';
  END IF;

  INSERT INTO public.permission_roles (id, tenant_id, name, description, is_admin_role)
  VALUES (gen_random_uuid(), v_tenant_id, 'TIH Manager', 'View and assess direct reports skills', false)
  ON CONFLICT (tenant_id, name) DO NOTHING
  RETURNING id INTO v_role_manager;
  IF v_role_manager IS NULL THEN
    SELECT id INTO v_role_manager FROM public.permission_roles
    WHERE tenant_id = v_tenant_id AND name = 'TIH Manager';
  END IF;

  INSERT INTO public.permission_roles (id, tenant_id, name, description, is_admin_role)
  VALUES (gen_random_uuid(), v_tenant_id, 'TIH HR Admin', 'Full TIH administration', false)
  ON CONFLICT (tenant_id, name) DO NOTHING
  RETURNING id INTO v_role_hr_admin;
  IF v_role_hr_admin IS NULL THEN
    SELECT id INTO v_role_hr_admin FROM public.permission_roles
    WHERE tenant_id = v_tenant_id AND name = 'TIH HR Admin';
  END IF;

  -- Reuse existing admin role for owner
  SELECT id INTO v_role_admin FROM public.permission_roles
  WHERE tenant_id = v_tenant_id AND is_admin_role = true LIMIT 1;

  -- ─── Role Permissions ─────────────────────────────────────────────

  -- Employee: view own skills, edit own assessment
  INSERT INTO public.role_permissions (tenant_id, role_id, permission_name) VALUES
    (v_tenant_id, v_role_employee, 'tih.employee_skills.view'),
    (v_tenant_id, v_role_employee, 'tih.employee_skills.edit')
  ON CONFLICT (role_id, permission_name) DO NOTHING;

  -- Manager: view/edit direct reports skills, view ontology
  INSERT INTO public.role_permissions (tenant_id, role_id, permission_name) VALUES
    (v_tenant_id, v_role_manager, 'tih.employee_skills.view'),
    (v_tenant_id, v_role_manager, 'tih.employee_skills.edit'),
    (v_tenant_id, v_role_manager, 'tih.ontology.view'),
    (v_tenant_id, v_role_manager, 'tih.job_requirements.view')
  ON CONFLICT (role_id, permission_name) DO NOTHING;

  -- HR Admin: full TIH access
  INSERT INTO public.role_permissions (tenant_id, role_id, permission_name) VALUES
    (v_tenant_id, v_role_hr_admin, 'tih.ontology.view'),
    (v_tenant_id, v_role_hr_admin, 'tih.ontology.edit'),
    (v_tenant_id, v_role_hr_admin, 'tih.job_requirements.view'),
    (v_tenant_id, v_role_hr_admin, 'tih.job_requirements.edit'),
    (v_tenant_id, v_role_hr_admin, 'tih.employee_skills.view'),
    (v_tenant_id, v_role_hr_admin, 'tih.employee_skills.edit')
  ON CONFLICT (role_id, permission_name) DO NOTHING;

  -- Admin role (owner): full TIH access (if exists)
  IF v_role_admin IS NOT NULL THEN
    INSERT INTO public.role_permissions (tenant_id, role_id, permission_name) VALUES
      (v_tenant_id, v_role_admin, 'tih.ontology.view'),
      (v_tenant_id, v_role_admin, 'tih.ontology.edit'),
      (v_tenant_id, v_role_admin, 'tih.job_requirements.view'),
      (v_tenant_id, v_role_admin, 'tih.job_requirements.edit'),
      (v_tenant_id, v_role_admin, 'tih.employee_skills.view'),
      (v_tenant_id, v_role_admin, 'tih.employee_skills.edit')
    ON CONFLICT (role_id, permission_name) DO NOTHING;
  END IF;

  -- ─── Role Assignments (group → role → target population) ──────────

  -- Employee role: all employees → self assessment on self only
  INSERT INTO public.role_assignments (tenant_id, role_id, granted_group_id, target_population_group_id)
  VALUES (v_tenant_id, v_role_employee, v_pg_all, v_pg_self)
  ON CONFLICT DO NOTHING;

  -- Manager role: all employees → skills of direct reports
  INSERT INTO public.role_assignments (tenant_id, role_id, granted_group_id, target_population_group_id)
  VALUES (v_tenant_id, v_role_manager, v_pg_all, v_pg_direct)
  ON CONFLICT DO NOTHING;

  -- HR Admin role: all employees → all employees
  INSERT INTO public.role_assignments (tenant_id, role_id, granted_group_id, target_population_group_id)
  VALUES (v_tenant_id, v_role_hr_admin, v_pg_all, v_pg_all)
  ON CONFLICT DO NOTHING;

  -- Admin (owner) role: all employees → all employees
  IF v_role_admin IS NOT NULL THEN
    INSERT INTO public.role_assignments (tenant_id, role_id, granted_group_id, target_population_group_id)
    VALUES (v_tenant_id, v_role_admin, v_pg_all, v_pg_all)
    ON CONFLICT DO NOTHING;
  END IF;

END $$;
