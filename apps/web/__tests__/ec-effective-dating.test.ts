import { describe, it, expect } from "vitest";

/**
 * Unit tests for effective-dating logic.
 * These validate the date-range arithmetic that insert_effective_record
 * and the UI rely on, without hitting the database.
 */

function dateRangesOverlap(
  a: { start: string; end: string | null },
  b: { start: string; end: string | null }
): boolean {
  const aStart = new Date(a.start).getTime();
  const aEnd = a.end ? new Date(a.end).getTime() : Infinity;
  const bStart = new Date(b.start).getTime();
  const bEnd = b.end ? new Date(b.end).getTime() : Infinity;
  return aStart < bEnd && bStart < aEnd;
}

function autoCloseDate(existingStart: string, newStart: string): string | null {
  const eStart = new Date(existingStart);
  const nStart = new Date(newStart);
  if (nStart <= eStart) return null;
  const closeDate = new Date(nStart);
  closeDate.setDate(closeDate.getDate() - 1);
  return closeDate.toISOString().slice(0, 10);
}

function effectiveAt<T extends { start_date: string; end_date: string | null }>(
  records: T[],
  asOf: string
): T | null {
  const target = new Date(asOf).getTime();
  return (
    records.find((r) => {
      const start = new Date(r.start_date).getTime();
      const end = r.end_date ? new Date(r.end_date).getTime() : Infinity;
      return target >= start && target < end;
    }) ?? null
  );
}

describe("effective-dating: overlap detection", () => {
  it("detects overlapping open-ended ranges", () => {
    const a = { start: "2024-01-01", end: null };
    const b = { start: "2024-06-01", end: null };
    expect(dateRangesOverlap(a, b)).toBe(true);
  });

  it("detects overlap when new range starts inside existing", () => {
    const existing = { start: "2024-01-01", end: "2024-12-31" };
    const incoming = { start: "2024-06-01", end: null };
    expect(dateRangesOverlap(existing, incoming)).toBe(true);
  });

  it("returns false for non-overlapping ranges", () => {
    const a = { start: "2024-01-01", end: "2024-06-01" };
    const b = { start: "2024-06-01", end: null };
    expect(dateRangesOverlap(a, b)).toBe(false);
  });

  it("returns false for adjacent ranges (end = next start)", () => {
    const a = { start: "2024-01-01", end: "2024-07-01" };
    const b = { start: "2024-07-01", end: null };
    expect(dateRangesOverlap(a, b)).toBe(false);
  });

  it("detects overlap for same-day ranges", () => {
    const a = { start: "2024-06-01", end: null };
    const b = { start: "2024-06-01", end: null };
    expect(dateRangesOverlap(a, b)).toBe(true);
  });
});

describe("effective-dating: auto-close", () => {
  it("closes previous record to day before new start", () => {
    expect(autoCloseDate("2024-01-01", "2024-07-01")).toBe("2024-06-30");
  });

  it("handles month boundaries", () => {
    expect(autoCloseDate("2024-01-01", "2024-03-01")).toBe("2024-02-29");
  });

  it("handles year boundaries", () => {
    expect(autoCloseDate("2024-06-01", "2025-01-01")).toBe("2024-12-31");
  });

  it("returns null if new start is before or equal to existing", () => {
    expect(autoCloseDate("2024-06-01", "2024-01-01")).toBeNull();
    expect(autoCloseDate("2024-06-01", "2024-06-01")).toBeNull();
  });
});

describe("effective-dating: query at date", () => {
  const records = [
    { id: "r1", start_date: "2024-01-01", end_date: "2024-06-30", title: "Junior" },
    { id: "r2", start_date: "2024-07-01", end_date: "2024-12-31", title: "Mid" },
    { id: "r3", start_date: "2025-01-01", end_date: null, title: "Senior" },
  ];

  it("returns correct record for date within first range", () => {
    const result = effectiveAt(records, "2024-03-15");
    expect(result?.title).toBe("Junior");
  });

  it("returns correct record for date within second range", () => {
    const result = effectiveAt(records, "2024-09-01");
    expect(result?.title).toBe("Mid");
  });

  it("returns open-ended record for current date", () => {
    const result = effectiveAt(records, "2025-06-01");
    expect(result?.title).toBe("Senior");
  });

  it("returns null for date before all records", () => {
    const result = effectiveAt(records, "2023-12-31");
    expect(result).toBeNull();
  });

  it("returns record whose start_date matches exactly", () => {
    const result = effectiveAt(records, "2024-07-01");
    expect(result?.title).toBe("Mid");
  });

  it("end_date is exclusive upper bound", () => {
    const result = effectiveAt(records, "2024-06-30");
    expect(result).toBeNull();
  });
});
