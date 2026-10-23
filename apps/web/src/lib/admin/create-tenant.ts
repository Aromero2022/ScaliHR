"use server";

import { createClient } from "@/lib/supabase/server";
import { adminPrisma, Prisma } from "@/lib/db/admin-client";
import { createTenantSchema, type CreateTenantInput } from "@/lib/validations/tenant";
import { revalidatePath } from "next/cache";

export async function createTenant(input: CreateTenantInput) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return { error: "No autenticado" };

  const parsed = createTenantSchema.safeParse(input);
  if (!parsed.success) {
    return { error: parsed.error.issues[0].message };
  }

  const { name, slug, rfc, modules } = parsed.data;

  try {
    const result = await adminPrisma.$transaction(async (tx) => {
      const tenant = await tx.tenant.create({
        data: {
          name,
          slug,
          domain: rfc || null,
          is_ec_active: modules.employee_central,
          is_rcm_active: modules.recruiting,
          is_pmgm_active: modules.performance,
          is_lms_active: modules.lms,
        },
      });

      await tx.$executeRaw(
        Prisma.sql`
          INSERT INTO public.user_tenant_memberships (user_id, tenant_id, app_role, is_active)
          VALUES (${user.id}::uuid, ${tenant.id}::uuid, 'owner', true)
        `
      );

      await tx.$executeRaw(
        Prisma.sql`
          INSERT INTO public.user_settings (user_id, active_tenant_id)
          VALUES (${user.id}::uuid, ${tenant.id}::uuid)
          ON CONFLICT (user_id) DO UPDATE SET active_tenant_id = EXCLUDED.active_tenant_id
        `
      );

      return tenant;
    });

    await supabase.auth.refreshSession();
    revalidatePath("/", "layout");

    return { success: true, tenantId: result.id };
  } catch (err) {
    const message =
      err instanceof Error ? err.message : "Error al crear el tenant";

    if (message.includes("unique") || message.includes("duplicate")) {
      return { error: "Ya existe una organización con ese slug" };
    }

    return { error: message };
  }
}
