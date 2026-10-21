import { createClient, type SupabaseClient, type SupportedStorage } from "@supabase/supabase-js";

export interface SupabaseClientOptions {
  url: string;
  anonKey: string;
  storage?: SupportedStorage;
}

export function createSupabaseClient(opts: SupabaseClientOptions): SupabaseClient {
  return createClient(opts.url, opts.anonKey, {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: typeof window !== "undefined",
      ...(opts.storage ? { storage: opts.storage } : {}),
    },
  });
}
