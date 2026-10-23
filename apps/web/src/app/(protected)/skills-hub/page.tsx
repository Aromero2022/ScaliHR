import { createClient } from "@/lib/supabase/server";
import { redirect, notFound } from "next/navigation";
import { getModuleFlags } from "@/lib/tenant/get-module-flags";
import SkillsHubDashboard from "@/components/skills-hub-dashboard";

interface SkillOntologyRow {
  id: string;
  code: string;
  name: string;
  description: string | null;
  category: string;
  is_active: boolean;
}

interface EmployeeSkillRow {
  skill_id: string;
  self_assessed_level: number;
  manager_assessed_level: number | null;
  skill: { name: string; code: string; category: string }[] | { name: string; code: string; category: string } | null;
}

interface JobRoleSkillRow {
  skill_id: string;
  required_proficiency_level: number;
  skill: { name: string; code: string; category: string }[] | { name: string; code: string; category: string } | null;
}

export default async function SkillsHubPage() {
  const supabase = await createClient();
  const {
    data: { user: authUser },
  } = await supabase.auth.getUser();
  if (!authUser) redirect("/login");

  const { data: bizUser } = await supabase
    .from("users")
    .select("id, tenant_id, position_id")
    .eq("auth_uid", authUser.id)
    .single();

  if (!bizUser) redirect("/login");

  const flags = await getModuleFlags(bizUser.tenant_id);
  if (!flags.is_tih_active) {
    notFound();
  }

  let jobRoleId: string | null = null;
  if (bizUser.position_id) {
    const { data: pos } = await supabase
      .from("positions")
      .select("job_classification_id")
      .eq("id", bizUser.position_id)
      .single();
    if (pos?.job_classification_id) {
      const { data: jc } = await supabase
        .from("job_classifications")
        .select("job_role_id")
        .eq("id", pos.job_classification_id)
        .single();
      jobRoleId = jc?.job_role_id ?? null;
    }
  }

  const [ontologyRes, mySkillsRes, roleSkillsRes] = await Promise.all([
    supabase
      .from("skill_ontology")
      .select("id, code, name, description, category, is_active")
      .eq("is_active", true)
      .order("category")
      .order("name"),
    supabase
      .from("employee_skills")
      .select(
        "skill_id, self_assessed_level, manager_assessed_level, skill:skill_ontology!es_skill_fk(name, code, category)"
      )
      .eq("user_id", bizUser.id),
    jobRoleId
      ? supabase
          .from("job_role_skills")
          .select(
            "skill_id, required_proficiency_level, skill:skill_ontology!jrs_skill_fk(name, code, category)"
          )
          .eq("job_role_id", jobRoleId)
      : Promise.resolve({ data: [] as JobRoleSkillRow[] }),
  ]);

  const ontology: SkillOntologyRow[] = (ontologyRes.data ?? []).map((s) => ({
    id: s.id as string,
    code: s.code as string,
    name: s.name as string,
    description: s.description as string | null,
    category: s.category as string,
    is_active: s.is_active as boolean,
  }));

  const mySkills = (mySkillsRes.data ?? []).map((es: unknown) => {
    const row = es as EmployeeSkillRow;
    const skill = Array.isArray(row.skill) ? row.skill[0] : row.skill;
    return {
      skill_id: row.skill_id,
      self_assessed_level: row.self_assessed_level,
      manager_assessed_level: row.manager_assessed_level,
      skill_name: skill?.name ?? "",
      skill_code: skill?.code ?? "",
      skill_category: skill?.category ?? "",
    };
  });

  const roleSkills = ((roleSkillsRes.data ?? []) as unknown[]).map((jrs) => {
    const row = jrs as JobRoleSkillRow;
    const skill = Array.isArray(row.skill) ? row.skill[0] : row.skill;
    return {
      skill_id: row.skill_id,
      required_level: row.required_proficiency_level,
      skill_name: skill?.name ?? "",
      skill_code: skill?.code ?? "",
      skill_category: skill?.category ?? "",
    };
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Talent Intelligence Hub</h1>
        <p className="mt-1 text-sm text-slate-400">
          TIH — Gestiona tus competencias, compara tu perfil y explora la ontología de habilidades
        </p>
      </div>
      <SkillsHubDashboard
        ontology={ontology}
        mySkills={mySkills}
        roleSkills={roleSkills}
      />
    </div>
  );
}
