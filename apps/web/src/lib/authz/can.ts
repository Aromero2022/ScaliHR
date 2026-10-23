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
  action: RbpAction,
  targetUserId?: string,
  fieldKey?: string
): Promise<CanResult> {
  const memberships = await prisma.group_members.findMany({
    where: { user_id: userId },
    select: { group_id: true },
  });

  if (memberships.length === 0) {
    return { allowed: false, reason: "no_group_membership" };
  }

  const groupIds = memberships.map((m) => m.group_id);

  const grants = await prisma.role_grants.findMany({
    where: { granted_group_id: { in: groupIds } },
    select: {
      role_id: true,
      target_population: true,
    },
  });

  if (grants.length === 0) {
    return { allowed: false, reason: "no_role_grants" };
  }

  const roleIds = grants.map((g) => g.role_id);

  const fieldCondition = fieldKey
    ? { OR: [{ field_key: fieldKey }, { field_key: null }] }
    : {};

  const permissions = await prisma.role_permissions.findMany({
    where: {
      role_id: { in: roleIds },
      permission_key: permissionKey,
      action: action === "edit" ? "edit" : { in: ["view", "edit"] },
      ...fieldCondition,
    },
    select: { role_id: true },
  });

  if (permissions.length === 0) {
    return { allowed: false, reason: "no_permission" };
  }

  const permittedRoleIds = new Set(permissions.map((p) => p.role_id));

  if (!targetUserId || targetUserId === userId) {
    const hasAny = grants.some((g) => permittedRoleIds.has(g.role_id));
    return hasAny
      ? { allowed: true }
      : { allowed: false, reason: "no_matching_grant" };
  }

  for (const grant of grants) {
    if (!permittedRoleIds.has(grant.role_id)) continue;

    switch (grant.target_population) {
      case "all":
        return { allowed: true };

      case "self":
        if (targetUserId === userId) return { allowed: true };
        break;

      case "same_department": {
        const [actor, target] = await Promise.all([
          prisma.users.findUnique({
            where: { id: userId },
            select: { department_id: true },
          }),
          prisma.users.findUnique({
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
        const target = await prisma.users.findUnique({
          where: { id: targetUserId },
          select: { manager_id: true },
        });
        if (target?.manager_id === userId) {
          return { allowed: true };
        }
        break;
      }
    }
  }

  return { allowed: false, reason: "target_population_mismatch" };
}
