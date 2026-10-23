import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import Link from "next/link";
import RoleManager from "@/components/role-manager";

export interface PermissionRoleRow {
  id: string;
  name: string;
  description: string | null;
  is_admin_role: boolean;
  permissions: { permission_name: string }[];
  assignments: {
    id: string;
    granted_group: { name: string } | null;
    target_population: { name: string } | null;
  }[];
}

export default async function ManageRolesPage() {
  const supabase = await createClient();
  const {
    data: { user: authUser },
  } = await supabase.auth.getUser();
  if (!authUser) redirect("/login");

  const { data: roles } = await supabase
    .from("permission_roles")
    .select(
      `id, name, description, is_admin_role,
       permissions:role_permissions(permission_name),
       assignments:role_assignments(id, granted_group:permission_groups!role_assignments_granted_group_id_fkey(name), target_population:permission_groups!role_assignments_target_population_group_id_fkey(name))`
    )
    .order("name");

  const { data: groups } = await supabase
    .from("permission_groups")
    .select("id, name, description, criteria_json")
    .order("name");

  const roleRows: PermissionRoleRow[] = (roles ?? []).map((r) => ({
    id: r.id,
    name: r.name,
    description: r.description,
    is_admin_role: r.is_admin_role,
    permissions: Array.isArray(r.permissions) ? r.permissions : [],
    assignments: (Array.isArray(r.assignments) ? r.assignments : []).map(
      (a: Record<string, unknown>) => ({
        id: a.id as string,
        granted_group: Array.isArray(a.granted_group)
          ? (a.granted_group[0] as { name: string } | null)
          : (a.granted_group as { name: string } | null),
        target_population: Array.isArray(a.target_population)
          ? (a.target_population[0] as { name: string } | null)
          : (a.target_population as { name: string } | null),
      })
    ),
  }));

  const groupList = (groups ?? []).map((g) => ({
    id: g.id as string,
    name: g.name as string,
    description: g.description as string | null,
    criteria_json: g.criteria_json,
  }));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-2">
            <Link
              href="/admin-center"
              className="text-sm text-slate-400 transition hover:text-slate-200"
            >
              Admin Center
            </Link>
            <span className="text-slate-600">/</span>
            <span className="text-sm text-slate-300">Gestión de Roles</span>
          </div>
          <h1 className="mt-2 text-2xl font-bold text-white">
            Role-Based Permissions
          </h1>
          <p className="mt-1 text-sm text-slate-400">
            Roles de permiso, permisos técnicos asignados y asignaciones de
            grupo
          </p>
        </div>
      </div>

      <RoleManager roles={roleRows} groups={groupList} />
    </div>
  );
}
