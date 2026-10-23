import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

const PUBLIC_PATHS = ["/login", "/auth", "/signup"];
const AAL2_PATHS = ["/admin-center"];
const MFA_PATHS = ["/mfa/enroll", "/mfa/verify"];
const MFA_REQUIRED_ROLES = ["owner", "hr_admin"];

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isPublic = PUBLIC_PATHS.some((p) =>
    request.nextUrl.pathname.startsWith(p)
  );

  if (!user && !isPublic) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  if (user) {
    const isMfaPath = MFA_PATHS.some((p) =>
      request.nextUrl.pathname.startsWith(p)
    );

    if (!isMfaPath) {
      const appRole = (user.app_metadata?.app_role as string) ?? "";
      const hasVerifiedTotp = user.factors?.some(
        (f) => f.status === "verified" && f.factor_type === "totp"
      );

      if (MFA_REQUIRED_ROLES.includes(appRole) && !hasVerifiedTotp) {
        const url = request.nextUrl.clone();
        url.pathname = "/mfa/enroll";
        url.searchParams.set("next", request.nextUrl.pathname);
        return NextResponse.redirect(url);
      }
    }

    const requiresAal2 = AAL2_PATHS.some((p) =>
      request.nextUrl.pathname.startsWith(p)
    );

    if (requiresAal2) {
      const { data } =
        await supabase.auth.mfa.getAuthenticatorAssuranceLevel();

      if (data?.currentLevel !== "aal2") {
        const url = request.nextUrl.clone();
        url.pathname = "/mfa/verify";
        url.searchParams.set("next", request.nextUrl.pathname);
        return NextResponse.redirect(url);
      }
    }
  }

  return supabaseResponse;
}
