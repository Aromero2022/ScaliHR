import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/db/tenant-client";

type RbpAction = "view" | "edit";

type CanResult = {
  allowed: boolean;
  reason?: string;
};

const requestCache = new Map<string, CanResult>();

function cacheKey(
  userId: string,
  permissionKey: string,
  action: RbpAction,
  targetUserId?: string,
  fieldKey?: string
): string {
  return `${userId}:${permissionKey}:${action}:${targetUserId ?? ""}:${fieldKey ?? ""}`;
}

export async function can(
  userId: string,
  permissionKey: string,
  action: RbpAction,
  targetUserId?: string,
  fieldKey?: string
): Promise<CanResult> {
  const key = cacheKey(userId, permissionKey, action, targetUserId, fieldKey);
  const cached = requestCache.get(key);
  if (cached) return cached;

  const result = await evaluate(
    userId,
    permissionKey,
    action,
    targetUserId,
    fieldKey
  );
  requestCache.set(key, result);
  return result;
}

export function clearCanCache() {
  requestCache.clear();
}

async function evaluate(
  userId: string,
  permissionKey: string,
  _action: RbpAction,
  targetUserId?: string,
  _fieldKey?: string
): Promise<CanResult> {
  const assignments = await prisma.roleAssignment.findMany({
    where: {
      granted_group: {
        criteria_json: {
          path: ["user_ids"],
          array_contains: userId,
        },
      },
    },
    select: {
      role_id: true,
      target_population: {
        select: { criteria_json: true },
      },
    },
  });

  if (assignments.length === 0) {
    return { allowed: false, reason: "no_group_membership" };
  }

  const roleIds = assignments.map((a) => a.role_id);

  const permissions = await prisma.rolePermission.findMany({
    where: {
      role_id: { in: roleIds },
      permission_name: permissionKey,
    },
    select: { role_id: true },
  });

  if (permissions.length === 0) {
    return { allowed: false, reason: "no_permission" };
  }

  const permittedRoleIds = new Set(permissions.map((p) => p.role_id));

  if (!targetUserId || targetUserId === userId) {
    const hasAny = assignments.some((a) => permittedRoleIds.has(a.role_id));
    return hasAny
      ? { allowed: true }
      : { allowed: false, reason: "no_matching_grant" };
  }

  for (const assignment of assignments) {
    if (!permittedRoleIds.has(assignment.role_id)) continue;

    const criteria = assignment.target_population?.criteria_json as
      | Record<string, unknown>
      | null;
    const populationType =
      (criteria?.type as string | undefined) ?? "all";

    switch (populationType) {
      case "all":
        return { allowed: true };

      case "self":
        if (targetUserId === userId) return { allowed: true };
        break;

      case "same_department": {
        const [actor, target] = await Promise.all([
          prisma.user.findUnique({
            where: { id: userId },
            select: { department_id: true },
          }),
          prisma.user.findUnique({
            where: { id: targetUserId },
            select: { department_id: true },
          }),
        ]);
        if (
          actor?.department_id &&
          target?.department_id &&
          actor.department_id === target.department_id
        ) {
          return { allowed: true };
        }
        break;
      }

      case "direct_reports": {
        const rows = await prisma.$queryRaw<{ manager_id: string | null }[]>(
          Prisma.sql`
            SELECT manager_id FROM public.ec_job_information
            WHERE user_id = ${targetUserId}::uuid
              AND end_date IS NULL
            ORDER BY start_date DESC, sequence DESC
            LIMIT 1
          `
        );
        if (rows.length > 0 && rows[0].manager_id === userId) {
          return { allowed: true };
        }
        break;
      }
    }
  }

  return { allowed: false, reason: "target_population_mismatch" };
}
