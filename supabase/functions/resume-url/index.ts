import {
  adminClient,
  CORS_HEADERS,
  EndpointError,
  errorResponse,
  isUuid,
  json,
  rpcError,
  userClient,
  userIdFrom,
} from "./runtime.ts";
export interface Deps {
  authenticate(req: Request): Promise<string | null>;
  path(req: Request, application: string): Promise<string>;
  sign(path: string, seconds: number): Promise<string>;
}
export function createHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
    if (req.method !== "POST") return errorResponse(405, "method_not_allowed");
    if (!await deps.authenticate(req).catch(() => null)) return errorResponse(401, "unauthorized");
    const body = await req.json().catch(() => null);
    if (!isUuid(body?.application_id)) return errorResponse(400, "invalid_request");
    try {
      const path = await deps.path(req, body.application_id);
      return json({ url: await deps.sign(path, 600) });
    } catch (error) {
      return error instanceof EndpointError ? errorResponse(error.status, error.code) : errorResponse(500, "internal");
    }
  };
}
if (import.meta.main) {
  Deno.serve(createHandler({
    authenticate: userIdFrom,
    async path(req, application) {
      const { data, error } = await userClient(req).rpc("get_resume_access", { p_application_id: application });
      rpcError(error);
      if (typeof data !== "string" || !data) throw new EndpointError(404, "resume_not_available");
      return data;
    },
    async sign(path, seconds) {
      const { data, error } = await adminClient().storage.from("resumes").createSignedUrl(path, seconds);
      if (error || !data?.signedUrl) throw new EndpointError(500, "internal");
      // Local containers use kong:8000 internally; apps need the configured public origin.
      const origin = new URL(Deno.env.get("PUBLIC_SUPABASE_URL") ?? Deno.env.get("SUPABASE_URL")!);
      if (
        origin.protocol !== "https:" &&
        !(origin.protocol === "http:" && ["localhost", "127.0.0.1", "[::1]", "10.0.2.2"].includes(origin.hostname))
      ) {
        throw new EndpointError(500, "internal");
      }
      const signed = new URL(data.signedUrl);
      return new URL(signed.pathname + signed.search, origin.origin).href;
    },
  }));
}
