import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn(),
}));

vi.mock("@/lib/tenant/get-module-flags", () => ({
  getModuleFlags: vi.fn(),
}));

vi.mock("@/lib/lms/moodle-client", () => ({
  getUser: vi.fn(),
  createUser: vi.fn(),
  addCohortMembers: vi.fn(),
  requestLoginUrl: vi.fn(),
}));

import { createClient } from "@/lib/supabase/server";
import { getModuleFlags } from "@/lib/tenant/get-module-flags";
import * as moodleClient from "@/lib/lms/moodle-client";
import { GET } from "@/app/(protected)/lms/launch/route";
import { NextRequest } from "next/server";

const mockGetModuleFlags = vi.mocked(getModuleFlags);
const mockMoodle = vi.mocked(moodleClient);

function makeRequest(url = "http://localhost:3000/lms/launch"): NextRequest {
  return new NextRequest(url);
}

function mockSupabaseUser(user: unknown) {
  const supabase = {
    auth: { getUser: vi.fn().mockResolvedValue({ data: { user }, error: null }) },
    from: vi.fn(() => {
      const chain: Record<string, unknown> = {};
      chain.select = vi.fn(() => chain);
      chain.eq = vi.fn(() => chain);
      chain.single = vi.fn().mockResolvedValue({ data: { moodle_cohort_id: 201 }, error: null });
      return chain;
    }),
  };
  (createClient as ReturnType<typeof vi.fn>).mockResolvedValue(supabase);
  return supabase;
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe("GET /lms/launch", () => {
  it("redirects to /login when there is no session", async () => {
    mockSupabaseUser(null);

    const res = await GET(makeRequest());

    expect(res.status).toBe(307);
    expect(new URL(res.headers.get("location")!).pathname).toBe("/login");
  });

  it("returns 404 when is_lms_active is false", async () => {
    mockSupabaseUser({
      id: "user-1",
      email: "test@acme.dev",
      app_metadata: { tenant_id: "tenant-1" },
      user_metadata: {},
    });
    mockGetModuleFlags.mockResolvedValue({
      is_ec_active: false, is_pmgm_active: false, is_sdm_active: false,
      is_rcm_active: false, is_lms_active: false, is_onb_active: false,
      is_comp_active: false, is_wfa_active: false, is_wfp_active: false,
      is_tme_active: false, is_tih_active: false,
    });

    const res = await GET(makeRequest());

    expect(res.status).toBe(404);
  });

  it("redirects to Moodle login URL with valid session and LMS flag", async () => {
    mockSupabaseUser({
      id: "user-1",
      email: "elena@acme.dev",
      app_metadata: { tenant_id: "tenant-1" },
      user_metadata: { first_name: "Elena", last_name: "Martinez" },
    });
    mockGetModuleFlags.mockResolvedValue({
      is_ec_active: false, is_pmgm_active: false, is_sdm_active: false,
      is_rcm_active: false, is_lms_active: true, is_onb_active: false,
      is_comp_active: false, is_wfa_active: false, is_wfp_active: false,
      is_tme_active: false, is_tih_active: false,
    });
    mockMoodle.getUser.mockResolvedValue({ id: 501, username: "user-1", email: "elena@acme.dev" });
    mockMoodle.requestLoginUrl.mockResolvedValue(
      "https://moodle.local/auth/userkey/login.php?key=abc123"
    );

    const res = await GET(makeRequest());

    expect(res.status).toBe(307);
    expect(res.headers.get("location")).toContain("moodle.local/auth/userkey/login.php");
    expect(mockMoodle.requestLoginUrl).toHaveBeenCalledWith("user-1");
  });

  it("provisions new Moodle user if not found", async () => {
    mockSupabaseUser({
      id: "user-2",
      email: "carlos@acme.dev",
      app_metadata: { tenant_id: "tenant-1" },
      user_metadata: { first_name: "Carlos", last_name: "Lopez" },
    });
    mockGetModuleFlags.mockResolvedValue({
      is_ec_active: false, is_pmgm_active: false, is_sdm_active: false,
      is_rcm_active: false, is_lms_active: true, is_onb_active: false,
      is_comp_active: false, is_wfa_active: false, is_wfp_active: false,
      is_tme_active: false, is_tih_active: false,
    });
    mockMoodle.getUser.mockResolvedValue(null);
    mockMoodle.createUser.mockResolvedValue({ id: 502, username: "user-2", email: "carlos@acme.dev" });
    mockMoodle.requestLoginUrl.mockResolvedValue("https://moodle.local/auth/userkey/login.php?key=xyz");

    const res = await GET(makeRequest());

    expect(res.status).toBe(307);
    expect(mockMoodle.createUser).toHaveBeenCalledWith({
      username: "user-2",
      email: "carlos@acme.dev",
      firstName: "Carlos",
      lastName: "Lopez",
    });
    expect(mockMoodle.addCohortMembers).toHaveBeenCalledWith(201, [502]);
  });

  it("returns 403 when user has no tenant", async () => {
    mockSupabaseUser({
      id: "user-3",
      email: "orphan@test.dev",
      app_metadata: {},
      user_metadata: {},
    });

    const res = await GET(makeRequest());

    expect(res.status).toBe(403);
  });
});
