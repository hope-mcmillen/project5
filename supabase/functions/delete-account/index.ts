import {
  adminClient,
  CORS_HEADERS,
  EndpointError,
  errorResponse,
  json,
  rpcError,
  userClient,
  userIdFrom,
} from "../resume-url/runtime.ts";
export interface Deps {
  authenticate(req: Request): Promise<string | null>;
  prepare(req: Request): Promise<void>;
  removeFiles(user: string): Promise<void>;
  removeUser(user: string): Promise<void>;
}
export function createHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
    if (req.method !== "POST") return errorResponse(405, "method_not_allowed");
    const user = await deps.authenticate(req).catch(() => null);
    if (!user) return errorResponse(401, "unauthorized");
    try {
      // No caller-selected user ID. Auth removal is last so failures can be retried.
      await deps.prepare(req);
      await deps.removeFiles(user);
      await deps.removeUser(user);
      return json({ deleted: true });
    } catch (error) {
      return error instanceof EndpointError ? errorResponse(error.status, error.code) : errorResponse(500, "internal");
    }
  };
}
if (import.meta.main) {
  Deno.serve(createHandler({
    authenticate: userIdFrom,
    async prepare(req) {
      const { error } = await userClient(req).rpc("prepare_account_deletion");
      rpcError(error);
    },
    async removeFiles(user) {
      const storage = adminClient().storage.from("resumes");
      // Valid uploads are flat UUID files under the user folder. Drain page zero
      // after every batch, avoiding skipped files when deleting more than one page.
      for (;;) {
        const { data, error } = await storage.list(user, { limit: 100, offset: 0 });
        if (error) throw new EndpointError(500, "internal");
        if (!data?.length) return;
        if (data.some((file) => !file.id)) throw new EndpointError(500, "internal");
        const removed = await storage.remove(data.map((file) => `${user}/${file.name}`));
        if (removed.error) throw new EndpointError(500, "internal");
      }
    },
    async removeUser(user) {
      const { error } = await adminClient().auth.admin.deleteUser(user);
      if (error) throw new EndpointError(500, "internal");
    },
  }));
}
