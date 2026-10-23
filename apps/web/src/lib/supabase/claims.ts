import { createClient } from "./server";

export type SessionClaims = {
  userId: string;
  email: string;
  tenantId: string | null;
  appRole: string | null;
  aal: string;
};

export async function getClaims(): Promise<SessionClaims | null> {
  const supabase = await createClient();

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) return null;

  const jwt = user.app_metadata ?? {};

  return {
    userId: user.id,
    email: user.email ?? "",
    tenantId: (jwt.tenant_id as string) ?? null,
    appRole: (jwt.app_role as string) ?? null,
    aal:
      (
        user.factors?.some(
          (f) => f.status === "verified" && f.factor_type === "totp"
        )
          ? "aal2"
          : "aal1"
      ),
  };
}

export async function requireAuth(): Promise<SessionClaims> {
  const claims = await getClaims();
  if (!claims) {
    const { redirect } = await import("next/navigation");
    redirect("/login");
  }
  return claims;
}

export async function requireAal2(): Promise<SessionClaims> {
  const claims = await requireAuth();

  const supabase = await createClient();
  const { data } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();

  if (data?.currentLevel !== "aal2") {
    const { redirect } = await import("next/navigation");
    redirect("/mfa/verify");
  }

  return claims;
}
