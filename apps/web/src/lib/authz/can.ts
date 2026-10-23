import { prisma, Prisma } from "@/lib/db/tenant-client";

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

type MatchingAssignment = {
  role_id: string;
  target_criteria: Record<string, unknown> | null;
};

async function findUserAssignments(
  userId: string
): Promise<MatchingAssignment[]> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { tenant_id: true },
  });
  if (!user) return [];

  const allAssignments = await prisma.roleAssignment.findMany({
    where: { tenant_id: user.tenant_id },
    select: {
      role_id: true,
      granted_group: { select: { criteria_json: true } },
      target_population: { select: { criteria_json: true } },
    },
  });

  return allAssignments
    .filter((a) => {
      const criteria = a.granted_group?.criteria_json as
        | Record<string, unknown>
        | null;
      if (!criteria) return false;
      const type = criteria.type as string | undefined;
      if (type === "all") return true;
      if (type === "self") return true;
      if (type === "direct_reports") return true;
      if (type === "user_ids") {
        const ids = criteria.user_ids as string[] | undefined;
        return ids?.includes(userId) ?? false;
      }
      return false;
    })
    .map((a) => ({
      role_id: a.role_id,
      target_criteria: a.target_population?.criteria_json as
        | Record<string, unknown>
        | null,
    }));
}

async function evaluate(
  userId: string,
  permissionKey: string,
  _action: RbpAction,
  targetUserId?: string,
  _fieldKey?: string
): Promise<CanResult> {
  const assignments = await findUserAssignments(userId);

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

    const populationType =
      (assignment.target_criteria?.type as string | undefined) ?? "all";

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
