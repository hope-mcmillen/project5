// Supabase clients for Edge Functions. The URL and keys are injected by the
// Supabase runtime (and by `supabase functions serve` locally).
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.117.2";

export type { SupabaseClient };

function env(key: string): string {
  const v = Deno.env.get(key);
  if (!v) throw new Error(`${key} is not set`);
  return v;
}

/** Service-role client: bypasses RLS. Use only after checking the caller's ownership yourself. */
export function adminClient(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** The caller's user id from their JWT, or null if missing/invalid. */
export async function userIdFrom(req: Request): Promise<string | null> {
  const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!jwt) return null;
  const anon = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await anon.auth.getUser(jwt);
  return error || !data.user ? null : data.user.id;
}
