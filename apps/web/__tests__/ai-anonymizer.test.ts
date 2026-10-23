import { describe, it, expect } from "vitest";
import { anonymizeForClaude, deanonymize } from "@/utils/ai-anonymizer";

describe("anonymizeForClaude", () => {
  it("replaces UUIDs with deterministic tokens", () => {
    const text = "User id: 550e8400-e29b-41d4-a716-446655440000";
    const { anonymized, map } = anonymizeForClaude(text);

    expect(anonymized).toBe("User id: [UUID_001]");
    expect(map.tokenToOriginal.get("[UUID_001]")).toBe(
      "550e8400-e29b-41d4-a716-446655440000"
    );
  });

  it("replaces the same UUID with the same token every time", () => {
    const uuid = "550e8400-e29b-41d4-a716-446655440000";
    const text = `First: ${uuid} and again: ${uuid}`;
    const { anonymized } = anonymizeForClaude(text);

    expect(anonymized).toBe("First: [UUID_001] and again: [UUID_001]");
  });

  it("assigns different tokens to different UUIDs", () => {
    const text =
      "a: 550e8400-e29b-41d4-a716-446655440000 b: 660e8400-e29b-41d4-a716-446655440001";
    const { anonymized } = anonymizeForClaude(text);

    expect(anonymized).toContain("[UUID_001]");
    expect(anonymized).toContain("[UUID_002]");
  });

  it("replaces CURP patterns", () => {
    const text = "CURP del empleado: GARC850101HDFRRL09";
    const { anonymized, map } = anonymizeForClaude(text);

    expect(anonymized).toBe("CURP del empleado: [CURP_001]");
    expect(map.tokenToOriginal.get("[CURP_001]")).toBe("GARC850101HDFRRL09");
  });

  it("replaces RFC patterns", () => {
    const text = "RFC: GARC850101AB3";
    const { anonymized, map } = anonymizeForClaude(text);

    expect(anonymized).toBe("RFC: [RFC_001]");
    expect(map.tokenToOriginal.get("[RFC_001]")).toBe("GARC850101AB3");
  });

  it("replaces email addresses", () => {
    const text = "Contacto: elena.martinez@acme.dev y soporte@empresa.com.mx";
    const { anonymized } = anonymizeForClaude(text);

    expect(anonymized).toContain("[EMAIL_001]");
    expect(anonymized).toContain("[EMAIL_002]");
    expect(anonymized).not.toContain("elena.martinez@acme.dev");
    expect(anonymized).not.toContain("soporte@empresa.com.mx");
  });

  it("replaces 11-digit NSS numbers", () => {
    const text = "NSS: 12345678901";
    const { anonymized } = anonymizeForClaude(text);

    expect(anonymized).toContain("[NSS_001]");
    expect(anonymized).not.toContain("12345678901");
  });

  it("replaces Mexican phone numbers (10+ digits)", () => {
    const text = "Tel: +52 55 1234 5678";
    const { anonymized } = anonymizeForClaude(text);

    expect(anonymized).toContain("[PHONE_001]");
    expect(anonymized).not.toContain("+52 55 1234 5678");
  });

  it("does not replace short numbers that are not phones", () => {
    const text = "Cantidad: 1234";
    const { anonymized } = anonymizeForClaude(text);

    expect(anonymized).toBe("Cantidad: 1234");
  });

  it("replaces known names (case-insensitive, longest first)", () => {
    const text = "Reporte de Elena Martinez y Carlos López";
    const { anonymized } = anonymizeForClaude(text, [
      "Elena Martinez",
      "Carlos López",
      "Elena",
    ]);

    expect(anonymized).toContain("[NAME_001]");
    expect(anonymized).toContain("[NAME_002]");
    expect(anonymized).not.toContain("Elena Martinez");
    expect(anonymized).not.toContain("Carlos López");
  });

  it("skips names shorter than 2 characters", () => {
    const text = "X marks the spot";
    const { anonymized } = anonymizeForClaude(text, ["X"]);

    expect(anonymized).toBe("X marks the spot");
  });

  it("handles text with no PII gracefully", () => {
    const text = "Departamento de Recursos Humanos, piso 3.";
    const { anonymized, map } = anonymizeForClaude(text);

    expect(anonymized).toBe(text);
    expect(map.tokenToOriginal.size).toBe(0);
  });

  it("handles mixed PII in a single string", () => {
    const text =
      "Elena (elena@acme.dev, CURP GARC850101HDFRRL09, tel +52 55 1234 5678)";
    const { anonymized } = anonymizeForClaude(text, ["Elena"]);

    expect(anonymized).not.toContain("elena@acme.dev");
    expect(anonymized).not.toContain("GARC850101HDFRRL09");
    expect(anonymized).not.toContain("+52 55 1234 5678");
    expect(anonymized).not.toContain("Elena");
  });
});

describe("deanonymize", () => {
  it("reverses all tokenized values", () => {
    const original =
      "User 550e8400-e29b-41d4-a716-446655440000 email elena@acme.dev";
    const { anonymized, map } = anonymizeForClaude(original);

    const restored = deanonymize(anonymized, map);
    expect(restored).toBe(original);
  });

  it("reverses tokens in AI-generated responses", () => {
    const { map } = anonymizeForClaude(
      "Employee: 550e8400-e29b-41d4-a716-446655440000"
    );

    const aiResponse = "The employee [UUID_001] has been evaluated.";
    const restored = deanonymize(aiResponse, map);

    expect(restored).toBe(
      "The employee 550e8400-e29b-41d4-a716-446655440000 has been evaluated."
    );
  });

  it("leaves text unchanged when map is empty", () => {
    const { map } = anonymizeForClaude("no PII here");
    const result = deanonymize("some AI output", map);

    expect(result).toBe("some AI output");
  });

  it("roundtrips complex PII text", () => {
    const original =
      "Elena Martinez (elena@acme.dev) - CURP: GARC850101HDFRRL09, RFC: GARC850101AB3";
    const names = ["Elena Martinez"];

    const { anonymized, map } = anonymizeForClaude(original, names);
    expect(anonymized).not.toContain("Elena Martinez");

    const restored = deanonymize(anonymized, map);
    expect(restored).toBe(original);
  });
});
