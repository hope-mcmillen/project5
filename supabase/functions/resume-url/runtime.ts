// A-owned runtime helpers; B's shared AI files remain untouched.
import { createClient } from "npm:@supabase/supabase-js@2.117.2";
export { CORS_HEADERS, errorResponse, isUuid, json } from "../_shared/http.ts";
export { adminClient, userIdFrom } from "../_shared/supabase.ts";
export function userClient(req: Request) {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
}
export class EndpointError extends Error {
  constructor(public status: number, public code: string) {
    super(code);
  }
}
export function rpcError(error: { message: string } | null): void {
  if (!error) return;
  const codes: Record<string, number> = {
    not_recruiter: 403,
    not_candidate: 403,
    not_owner: 404,
    resume_not_available: 404,
  };
  throw new EndpointError(codes[error.message] ?? 500, codes[error.message] ? error.message : "internal");
}
