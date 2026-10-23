import { describe, it, expect, vi, beforeEach } from "vitest";

const mockFindManyRoleAssignment = vi.fn();
const mockFindManyRolePermission = vi.fn();
const mockFindUniqueUser = vi.fn();
const mockQueryRaw = vi.fn();

vi.mock("@/lib/db/tenant-client", () => ({
  prisma: {
    roleAssignment: { findMany: (...args: unknown[]) => mockFindManyRoleAssignment(...args) },
    rolePermission: { findMany: (...args: unknown[]) => mockFindManyRolePermission(...args) },
    user: { findUnique: (...args: unknown[]) => mockFindUniqueUser(...args) },
    $queryRaw: (...args: unknown[]) => mockQueryRaw(...args),
  },
}));

vi.mock("@prisma/client", () => ({
  Prisma: { sql: (strings: TemplateStringsArray, ...values: unknown[]) => ({ strings, values }) },
}));

import { can, clearCanCache } from "@/lib/authz/can";

const USER_A = "user-a";
const USER_B = "user-b";
const ROLE_1 = "role-1";

function setupGrantPath(opts: {
  targetPopulation: string;
  hasPermission?: boolean;
}) {
  mockFindManyRoleAssignment.mockResolvedValue([
    {
      role_id: ROLE_1,
      target_population: {
        criteria_json: { type: opts.targetPopulation },
      },
    },
  ]);
  mockFindManyRolePermission.mockResolvedValue(
    opts.hasPermission !== false ? [{ role_id: ROLE_1 }] : []
  );
}

describe("can()", () => {
  beforeEach(() => {
    clearCanCache();
    vi.clearAllMocks();
  });

  it("denies when user has no group memberships", async () => {
    mockFindManyRoleAssignment.mockResolvedValue([]);
    const result = await can(USER_A, "employee.view", "view");
    expect(result.allowed).toBe(false);
    expect(result.reason).toBe("no_group_membership");
  });

  it("denies when no matching permissions exist", async () => {
    setupGrantPath({ targetPopulation: "all", hasPermission: false });
    const result = await can(USER_A, "employee.view", "view");
    expect(result.allowed).toBe(false);
    expect(result.reason).toBe("no_permission");
  });

  describe("target_population: all", () => {
    it("allows access to any target user", async () => {
      setupGrantPath({ targetPopulation: "all" });
      const result = await can(USER_A, "employee.view", "view", USER_B);
      expect(result.allowed).toBe(true);
    });

    it("allows access when no target is specified", async () => {
      setupGrantPath({ targetPopulation: "all" });
      const result = await can(USER_A, "employee.view", "view");
      expect(result.allowed).toBe(true);
    });
  });

  describe("target_population: self", () => {
    it("allows when target is the actor", async () => {
      setupGrantPath({ targetPopulation: "self" });
      const result = await can(USER_A, "employee.view", "view", USER_A);
      expect(result.allowed).toBe(true);
    });

    it("denies when target is a different user", async () => {
      setupGrantPath({ targetPopulation: "self" });
      const result = await can(USER_A, "employee.view", "view", USER_B);
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe("target_population_mismatch");
    });
  });

  describe("target_population: same_department", () => {
    it("allows when actor and target share a department", async () => {
      setupGrantPath({ targetPopulation: "same_department" });
      mockFindUniqueUser
        .mockResolvedValueOnce({ department_id: "dept-1" })
        .mockResolvedValueOnce({ department_id: "dept-1" });

      const result = await can(USER_A, "employee.view", "view", USER_B);
      expect(result.allowed).toBe(true);
    });

    it("denies when actor and target are in different departments", async () => {
      setupGrantPath({ targetPopulation: "same_department" });
      mockFindUniqueUser
        .mockResolvedValueOnce({ department_id: "dept-1" })
        .mockResolvedValueOnce({ department_id: "dept-2" });

      const result = await can(USER_A, "employee.view", "view", USER_B);
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe("target_population_mismatch");
    });

    it("denies when either user has no department", async () => {
      setupGrantPath({ targetPopulation: "same_department" });
      mockFindUniqueUser
        .mockResolvedValueOnce({ department_id: null })
        .mockResolvedValueOnce({ department_id: "dept-1" });

      const result = await can(USER_A, "employee.view", "view", USER_B);
      expect(result.allowed).toBe(false);
    });
  });

  describe("target_population: direct_reports", () => {
    it("allows when target's manager_id matches actor", async () => {
      setupGrantPath({ targetPopulation: "direct_reports" });
      mockQueryRaw.mockResolvedValue([{ manager_id: USER_A }]);

      const result = await can(USER_A, "employee.view", "view", USER_B);
      expect(result.allowed).toBe(true);
    });

    it("denies when target's manager is someone else", async () => {
      setupGrantPath({ targetPopulation: "direct_reports" });
      mockQueryRaw.mockResolvedValue([{ manager_id: "other-manager" }]);

      const result = await can(USER_A, "employee.view", "view", USER_B);
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe("target_population_mismatch");
    });

    it("denies when target has no manager", async () => {
      setupGrantPath({ targetPopulation: "direct_reports" });
      mockQueryRaw.mockResolvedValue([{ manager_id: null }]);

      const result = await can(USER_A, "employee.view", "view", USER_B);
      expect(result.allowed).toBe(false);
    });
  });

  describe("caching", () => {
    it("returns cached result on repeated calls with same args", async () => {
      setupGrantPath({ targetPopulation: "all" });
      await can(USER_A, "employee.view", "view");
      await can(USER_A, "employee.view", "view");

      expect(mockFindManyRoleAssignment).toHaveBeenCalledTimes(1);
    });

    it("evaluates separately for different permission keys", async () => {
      setupGrantPath({ targetPopulation: "all" });
      await can(USER_A, "employee.view", "view");

      clearCanCache();
      setupGrantPath({ targetPopulation: "all" });
      await can(USER_A, "compensation.view", "view");

      expect(mockFindManyRoleAssignment).toHaveBeenCalledTimes(2);
    });
  });
});
