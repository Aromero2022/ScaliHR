type EntityType =
  | "NAME"
  | "EMAIL"
  | "CURP"
  | "RFC"
  | "NSS"
  | "PHONE"
  | "UUID"
  | "EMPLOYEE_ID";

interface AnonymizationMap {
  tokenToOriginal: Map<string, string>;
  originalToToken: Map<string, string>;
  counter: Record<EntityType, number>;
}

function createMap(): AnonymizationMap {
  return {
    tokenToOriginal: new Map(),
    originalToToken: new Map(),
    counter: {
      NAME: 0,
      EMAIL: 0,
      CURP: 0,
      RFC: 0,
      NSS: 0,
      PHONE: 0,
      UUID: 0,
      EMPLOYEE_ID: 0,
    },
  };
}

function tokenize(map: AnonymizationMap, type: EntityType, value: string): string {
  const existing = map.originalToToken.get(value);
  if (existing) return existing;

  map.counter[type]++;
  const token = `[${type}_${String(map.counter[type]).padStart(3, "0")}]`;
  map.tokenToOriginal.set(token, value);
  map.originalToToken.set(value, token);
  return token;
}

const CURP_RE = /\b[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z\d]\d\b/g;
const RFC_RE = /\b[A-Z&Ñ]{3,4}\d{6}[A-Z\d]{3}\b/g;
const NSS_RE = /\b\d{11}\b/g;
const EMAIL_RE = /\b[\w.+-]+@[\w.-]+\.\w{2,}\b/g;
const PHONE_MX_RE = /\b(?:\+?52\s?)?(?:\(?\d{2,3}\)?[\s-]?)?\d{3,4}[\s-]?\d{4}\b/g;
const UUID_RE = /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi;

export function anonymizeForClaude(
  text: string,
  knownNames?: string[]
): { anonymized: string; map: AnonymizationMap } {
  const map = createMap();
  let result = text;

  result = result.replace(UUID_RE, (m) => tokenize(map, "UUID", m));
  result = result.replace(CURP_RE, (m) => tokenize(map, "CURP", m));
  result = result.replace(RFC_RE, (m) => tokenize(map, "RFC", m));
  result = result.replace(EMAIL_RE, (m) => tokenize(map, "EMAIL", m));
  result = result.replace(NSS_RE, (m) => tokenize(map, "NSS", m));
  result = result.replace(PHONE_MX_RE, (m) => {
    if (m.replace(/\D/g, "").length >= 10) {
      return tokenize(map, "PHONE", m);
    }
    return m;
  });

  if (knownNames && knownNames.length > 0) {
    const sorted = [...knownNames].sort((a, b) => b.length - a.length);
    for (const name of sorted) {
      if (name.length < 2) continue;
      const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const nameRe = new RegExp(`\\b${escaped}\\b`, "gi");
      result = result.replace(nameRe, () => tokenize(map, "NAME", name));
    }
  }

  return { anonymized: result, map };
}

export function deanonymize(text: string, map: AnonymizationMap): string {
  let result = text;
  for (const [token, original] of map.tokenToOriginal) {
    const escaped = token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    result = result.replace(new RegExp(escaped, "g"), original);
  }
  return result;
}
