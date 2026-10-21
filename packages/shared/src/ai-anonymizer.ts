type AnonymizedRecord = Record<string, unknown>;

const PII_PATTERNS: Record<string, RegExp> = {
  email: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
  phone: /^[\d\s+()-]{7,20}$/,
};

const SENSITIVE_KEYS = new Set([
  "first_name",
  "last_name",
  "email",
  "phone",
  "salary",
  "salary_min",
  "salary_max",
  "pay_band",
  "employee_id",
  "auth_uid",
  "address",
  "ssn",
  "national_id",
  "bank_account",
  "iban",
]);

const NAME_KEYS = new Set(["first_name", "last_name", "name", "full_name"]);
const SALARY_KEYS = new Set(["salary", "salary_min", "salary_max", "compensation", "bonus"]);
const EMAIL_KEYS = new Set(["email", "personal_email", "work_email"]);
const ID_KEYS = new Set(["employee_id", "auth_uid", "ssn", "national_id", "bank_account", "iban"]);

function maskValue(key: string, _value: unknown, index: number): unknown {
  if (NAME_KEYS.has(key)) return `Person_${index}`;
  if (EMAIL_KEYS.has(key)) return `person_${index}@redacted.local`;
  if (SALARY_KEYS.has(key)) return "[REDACTED_COMPENSATION]";
  if (ID_KEYS.has(key)) return `ID_${index}`;
  if (key === "phone") return "+0-000-000-0000";
  if (key === "address") return "[REDACTED_ADDRESS]";
  return "[REDACTED]";
}

function anonymizeObject(obj: AnonymizedRecord, index: number): AnonymizedRecord {
  const result: AnonymizedRecord = {};

  for (const [key, value] of Object.entries(obj)) {
    if (SENSITIVE_KEYS.has(key)) {
      result[key] = maskValue(key, value, index);
    } else if (typeof value === "string" && PII_PATTERNS.email.test(value)) {
      result[key] = `person_${index}@redacted.local`;
    } else if (value !== null && typeof value === "object" && !Array.isArray(value)) {
      result[key] = anonymizeObject(value as AnonymizedRecord, index);
    } else if (Array.isArray(value)) {
      result[key] = value.map((item, i) =>
        item !== null && typeof item === "object"
          ? anonymizeObject(item as AnonymizedRecord, index * 1000 + i)
          : item
      );
    } else {
      result[key] = value;
    }
  }

  return result;
}

export function anonymizeForClaude(data: unknown): unknown {
  if (data === null || data === undefined) return data;

  if (Array.isArray(data)) {
    return data.map((item, index) =>
      item !== null && typeof item === "object"
        ? anonymizeObject(item as AnonymizedRecord, index + 1)
        : item
    );
  }

  if (typeof data === "object") {
    return anonymizeObject(data as AnonymizedRecord, 1);
  }

  return data;
}
