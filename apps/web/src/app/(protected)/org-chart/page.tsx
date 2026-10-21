import { createClient } from "@/lib/supabase/server";

function extractField(rel: unknown, key: string): string | null {
  if (rel == null) return null;
  if (Array.isArray(rel)) return (rel[0] as Record<string, string>)?.[key] ?? null;
  return (rel as Record<string, string>)[key] ?? null;
}
import { redirect } from "next/navigation";
import OrgTree from "@/components/org-tree";
import type { OrgNode } from "@/components/org-tree";

export default async function OrgChartPage() {
  const supabase = await createClient();

  const {
    data: { user: authUser },
  } = await supabase.auth.getUser();

  if (!authUser) redirect("/login");

  const { data: employees } = await supabase
    .from("users")
    .select("id, first_name, last_name, email, manager_id, status, job_informations(title), departments(name)")
    .eq("status", "ACTIVE")
    .order("last_name", { ascending: true });

  const nodes: OrgNode[] = (employees ?? []).map((e) => ({
    id: e.id,
    first_name: e.first_name,
    last_name: e.last_name,
    email: e.email,
    manager_id: e.manager_id,
    status: e.status,
    job_title: extractField(e.job_informations, "title"),
    department_name: extractField(e.departments, "name"),
  }));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">
          Organigrama — Employee Central
        </h1>
        <p className="mt-1 text-sm text-slate-400">
          Estructura jerárquica de la organización ({nodes.length} empleados
          activos)
        </p>
      </div>

      <div className="rounded-xl border border-slate-800 bg-slate-900/50 p-8">
        <OrgTree nodes={nodes} />
      </div>
    </div>
  );
}
