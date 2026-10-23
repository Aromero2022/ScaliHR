"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export async function updateSelfAssessment(skillId: string, level: number) {
  const supabase = await createClient();
  const {
    data: { user: authUser },
  } = await supabase.auth.getUser();
  if (!authUser) return { error: "No autenticado" };

  const { data: bizUser } = await supabase
    .from("users")
    .select("id, tenant_id")
    .eq("auth_uid", authUser.id)
    .single();

  if (!bizUser) return { error: "Usuario no encontrado" };

  if (level < 1 || level > 5) return { error: "El nivel debe estar entre 1 y 5" };

  const { error } = await supabase
    .from("employee_skills")
    .upsert(
      {
        tenant_id: bizUser.tenant_id,
        user_id: bizUser.id,
        skill_id: skillId,
        self_assessed_level: level,
      },
      { onConflict: "user_id,skill_id" }
    );

  if (error) return { error: error.message };

  revalidatePath("/skills-hub");
  return { success: true };
}
