import { createClient } from "@/lib/supabase/server";

type RateLimitConfig = {
  maxTokens: number;
  windowSeconds: number;
};

const LIMITS: Record<string, RateLimitConfig> = {
  login: { maxTokens: 5, windowSeconds: 60 },
  mfa_verify: { maxTokens: 5, windowSeconds: 60 },
  tenant_create: { maxTokens: 3, windowSeconds: 3600 },
  api_action: { maxTokens: 30, windowSeconds: 60 },
};

export async function checkRateLimit(
  key: string,
  action: string
): Promise<{ allowed: boolean }> {
  const config = LIMITS[action] ?? { maxTokens: 10, windowSeconds: 60 };

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("check_rate_limit", {
    p_key: key,
    p_action: action,
    p_max_tokens: config.maxTokens,
    p_window_seconds: config.windowSeconds,
  });

  if (error) {
    return { allowed: true };
  }

  return { allowed: data === true };
}

export function getRateLimitConfig(action: string): RateLimitConfig | null {
  return LIMITS[action] ?? null;
}
