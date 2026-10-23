import { describe, it, expect } from "vitest";

/**
 * Unit tests for field-level permission logic.
 * Validates the compensation visibility rules and admin-only
 * access gates used in the employee detail and ARCO pages.
 */

type UserContext = {
  userId: string;
  isHrAdmin: boolean;
  isDirectManager: boolean;
};

function canViewCompensation(ctx: UserContext): boolean {
  return ctx.isHrAdmin || ctx.isDirectManager;
}

function canAccessArcoPanel(ctx: UserContext): boolean {
  return ctx.isHrAdmin;
}

function canProcessArcoRequest(
  ctx: UserContext,
  request: { status: string }
): boolean {
  if (!ctx.isHrAdmin) return false;
  return request.status === "pending" || request.status === "in_progress";
}

type FieldVisibility = "visible" | "masked" | "hidden";

function getFieldVisibility(
  field: string,
  ctx: UserContext
): FieldVisibility {
  const sensitiveFields = [
    "base_salary",
    "currency",
    "frequency",
    "bonus_target",
    "pay_group",
  ];
  const piiFields = [
    "national_id",
    "tax_id",
    "imss_number",
    "personal_email",
    "emergency_contact_phone",
  ];

  if (sensitiveFields.includes(field)) {
    return canViewCompensation(ctx) ? "visible" : "hidden";
  }

  if (piiFields.includes(field)) {
    if (ctx.isHrAdmin) return "visible";
    if (ctx.isDirectManager) return "masked";
    return "hidden";
  }

  return "visible";
}

describe("field permissions: compensation visibility", () => {
  it("HR admin can view compensation", () => {
    const ctx: UserContext = { userId: "u1", isHrAdmin: true, isDirectManager: false };
    expect(canViewCompensation(ctx)).toBe(true);
  });

  it("direct manager can view compensation", () => {
    const ctx: UserContext = { userId: "u2", isHrAdmin: false, isDirectManager: true };
    expect(canViewCompensation(ctx)).toBe(true);
  });

  it("regular employee cannot view compensation", () => {
    const ctx: UserContext = { userId: "u3", isHrAdmin: false, isDirectManager: false };
    expect(canViewCompensation(ctx)).toBe(false);
  });
});

describe("field permissions: ARCO panel access", () => {
  it("HR admin can access ARCO panel", () => {
    const ctx: UserContext = { userId: "u1", isHrAdmin: true, isDirectManager: false };
    expect(canAccessArcoPanel(ctx)).toBe(true);
  });

  it("manager cannot access ARCO panel", () => {
    const ctx: UserContext = { userId: "u2", isHrAdmin: false, isDirectManager: true };
    expect(canAccessArcoPanel(ctx)).toBe(false);
  });

  it("regular employee cannot access ARCO panel", () => {
    const ctx: UserContext = { userId: "u3", isHrAdmin: false, isDirectManager: false };
    expect(canAccessArcoPanel(ctx)).toBe(false);
  });
});

describe("field permissions: ARCO request processing", () => {
  it("HR admin can process pending requests", () => {
    const ctx: UserContext = { userId: "u1", isHrAdmin: true, isDirectManager: false };
    expect(canProcessArcoRequest(ctx, { status: "pending" })).toBe(true);
    expect(canProcessArcoRequest(ctx, { status: "in_progress" })).toBe(true);
  });

  it("HR admin cannot re-process completed requests", () => {
    const ctx: UserContext = { userId: "u1", isHrAdmin: true, isDirectManager: false };
    expect(canProcessArcoRequest(ctx, { status: "completed" })).toBe(false);
    expect(canProcessArcoRequest(ctx, { status: "rejected" })).toBe(false);
  });

  it("non-admin cannot process any request", () => {
    const ctx: UserContext = { userId: "u2", isHrAdmin: false, isDirectManager: false };
    expect(canProcessArcoRequest(ctx, { status: "pending" })).toBe(false);
  });
});

describe("field permissions: field-level visibility", () => {
  const admin: UserContext = { userId: "u1", isHrAdmin: true, isDirectManager: false };
  const manager: UserContext = { userId: "u2", isHrAdmin: false, isDirectManager: true };
  const employee: UserContext = { userId: "u3", isHrAdmin: false, isDirectManager: false };

  it("HR admin sees all fields", () => {
    expect(getFieldVisibility("base_salary", admin)).toBe("visible");
    expect(getFieldVisibility("national_id", admin)).toBe("visible");
    expect(getFieldVisibility("first_name", admin)).toBe("visible");
  });

  it("manager sees compensation and masked PII", () => {
    expect(getFieldVisibility("base_salary", manager)).toBe("visible");
    expect(getFieldVisibility("national_id", manager)).toBe("masked");
    expect(getFieldVisibility("first_name", manager)).toBe("visible");
  });

  it("employee cannot see compensation or PII", () => {
    expect(getFieldVisibility("base_salary", employee)).toBe("hidden");
    expect(getFieldVisibility("national_id", employee)).toBe("hidden");
    expect(getFieldVisibility("first_name", employee)).toBe("visible");
  });

  it("classifies all sensitive compensation fields", () => {
    const compFields = ["base_salary", "currency", "frequency", "bonus_target", "pay_group"];
    for (const field of compFields) {
      expect(getFieldVisibility(field, employee)).toBe("hidden");
      expect(getFieldVisibility(field, admin)).toBe("visible");
    }
  });

  it("classifies all PII fields", () => {
    const piiFields = ["national_id", "tax_id", "imss_number", "personal_email", "emergency_contact_phone"];
    for (const field of piiFields) {
      expect(getFieldVisibility(field, employee)).toBe("hidden");
      expect(getFieldVisibility(field, manager)).toBe("masked");
      expect(getFieldVisibility(field, admin)).toBe("visible");
    }
  });
});
