import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { getModuleFlags } from "@/lib/tenant/get-module-flags";
import * as moodle from "@/lib/lms/moodle-client";

export async function GET() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.redirect(new URL("/login", process.env.NEXT_PUBLIC_SUPABASE_URL ?? "http://localhost:3000"));
  }

  const tenantId = (user.app_metadata?.tenant_id as string) ?? null;
  if (!tenantId) {
    return NextResponse.json({ error: "No tenant asignado" }, { status: 403 });
  }

  const flags = await getModuleFlags(tenantId);
  if (!flags.is_lms_active) {
    return NextResponse.json(
      { error: "El módulo LMS no está habilitado para este tenant" },
      { status: 403 }
    );
  }

  const supabaseUuid = user.id;
  const email = user.email ?? "";
  const meta = user.user_metadata ?? {};
  const firstName = (meta.first_name as string) ?? email.split("@")[0];
  const lastName = (meta.last_name as string) ?? "";

  let moodleUser = await moodle.getUser("username", supabaseUuid);

  if (!moodleUser) {
    moodleUser = await moodle.createUser({
      username: supabaseUuid,
      email,
      firstName,
      lastName,
    });

    const { data: tenantMap } = await supabase
      .from("lms_tenant_map")
      .select("moodle_cohort_id")
      .eq("tenant_id", tenantId)
      .single();

    if (tenantMap?.moodle_cohort_id) {
      await moodle.addCohortMembers(tenantMap.moodle_cohort_id, [moodleUser.id]);
    }
  }

  const loginUrl = await moodle.requestLoginUrl(supabaseUuid);

  return NextResponse.redirect(loginUrl);
}
