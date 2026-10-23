import { describe, it, expect, vi, beforeEach } from "vitest";

const mockRpc = vi.fn();

vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn().mockResolvedValue({
    rpc: (...args: unknown[]) => mockRpc(...args),
  }),
}));

import { checkRateLimit, getRateLimitConfig } from "@/lib/rate-limit";

describe("checkRateLimit()", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("allows when RPC returns true", async () => {
    mockRpc.mockResolvedValue({ data: true, error: null });
    const result = await checkRateLimit("ip:1.2.3.4", "login");
    expect(result.allowed).toBe(true);
  });

  it("denies when RPC returns false", async () => {
    mockRpc.mockResolvedValue({ data: false, error: null });
    const result = await checkRateLimit("ip:1.2.3.4", "login");
    expect(result.allowed).toBe(false);
  });

  it("fails open when RPC errors", async () => {
    mockRpc.mockResolvedValue({ data: null, error: { message: "db error" } });
    const result = await checkRateLimit("ip:1.2.3.4", "login");
    expect(result.allowed).toBe(true);
  });

  it("passes correct params for login action", async () => {
    mockRpc.mockResolvedValue({ data: true, error: null });
    await checkRateLimit("ip:1.2.3.4", "login");

    expect(mockRpc).toHaveBeenCalledWith("check_rate_limit", {
      p_key: "ip:1.2.3.4",
      p_action: "login",
      p_max_tokens: 5,
      p_window_seconds: 60,
    });
  });

  it("passes correct params for tenant_create action", async () => {
    mockRpc.mockResolvedValue({ data: true, error: null });
    await checkRateLimit("user:abc", "tenant_create");

    expect(mockRpc).toHaveBeenCalledWith("check_rate_limit", {
      p_key: "user:abc",
      p_action: "tenant_create",
      p_max_tokens: 3,
      p_window_seconds: 3600,
    });
  });

  it("uses default config for unknown actions", async () => {
    mockRpc.mockResolvedValue({ data: true, error: null });
    await checkRateLimit("ip:1.2.3.4", "unknown_action");

    expect(mockRpc).toHaveBeenCalledWith("check_rate_limit", {
      p_key: "ip:1.2.3.4",
      p_action: "unknown_action",
      p_max_tokens: 10,
      p_window_seconds: 60,
    });
  });
});

describe("getRateLimitConfig()", () => {
  it("returns config for known actions", () => {
    expect(getRateLimitConfig("login")).toEqual({
      maxTokens: 5,
      windowSeconds: 60,
    });
    expect(getRateLimitConfig("mfa_verify")).toEqual({
      maxTokens: 5,
      windowSeconds: 60,
    });
    expect(getRateLimitConfig("tenant_create")).toEqual({
      maxTokens: 3,
      windowSeconds: 3600,
    });
    expect(getRateLimitConfig("api_action")).toEqual({
      maxTokens: 30,
      windowSeconds: 60,
    });
  });

  it("returns null for unknown actions", () => {
    expect(getRateLimitConfig("foo")).toBeNull();
  });
});
