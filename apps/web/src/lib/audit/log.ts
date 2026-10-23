import { createClient } from "@/lib/supabase/server";
import { headers } from "next/headers";

type AuditEntry = {
  tenantId: string;
  actorId: string;
  action: string;
  entity?: string;
  entityId?: string;
  diff?: Record<string, unknown>;
};

export async function writeAuditLog(entry: AuditEntry): Promise<string | null> {
  const supabase = await createClient();
  const headersList = await headers();

  const ip = headersList.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null;
  const userAgent = headersList.get("user-agent") ?? null;

  const { data, error } = await supabase.rpc("write_audit_log", {
    p_tenant_id: entry.tenantId,
    p_actor_id: entry.actorId,
    p_action: entry.action,
    p_entity: entry.entity ?? null,
    p_entity_id: entry.entityId ?? null,
    p_diff: entry.diff ?? null,
    p_ip: ip,
    p_user_agent: userAgent,
  });

  if (error) {
    console.error("[audit] write_audit_log failed:", error.message);
    return null;
  }

  return data as string;
}
