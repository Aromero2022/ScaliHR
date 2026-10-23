import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getModuleFlags, type ModuleFlags } from "@/lib/tenant/get-module-flags";
import Sidebar from "@/components/sidebar";

export default async function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const tenantId = (user.app_metadata?.tenant_id as string) ?? null;
  let moduleFlags: ModuleFlags | null = null;
  if (tenantId) {
    moduleFlags = await getModuleFlags(tenantId);
  }

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar moduleFlags={moduleFlags} />
      <main className="flex-1 overflow-y-auto p-8">{children}</main>
    </div>
  );
}
