// parse-resume Edge Function (B6 / AI-07). Contract: docs/API_CONTRACT.md §2.
//   POST { "resume_id": uuid }  with the candidate's JWT
//   → 200 { status: "READY", ... } | 200 { status: "FAILED", failure_reason }
//   → 400 invalid_request · 401 unauthorized · 403 not_owner · 404 resume_not_found · 409 already_parsing
import { CORS_HEADERS, errorResponse, isUuid, json } from "../_shared/http.ts";
import { LlmConfigError } from "../_shared/llm.ts";
import { type SkillDb, SupabaseSkillIndex } from "../_shared/normalize.ts";
import { type ParseDeps, ParseRequestError, parseResume } from "../_shared/resume_pipeline.ts";
import { SupabaseResumeRepo } from "../_shared/resume_repo.ts";
import { adminClient, userIdFrom } from "../_shared/supabase.ts";
import { getMeteredProvider, SupabaseUsageStore, type UsageDb } from "../_shared/usage.ts";

export interface HandlerDeps {
  authenticate(req: Request): Promise<string | null>;
  build(userId: string): ParseDeps;
}

export function createHandler(deps: HandlerDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
    if (req.method !== "POST") return errorResponse(405, "method_not_allowed");

    const userId = await deps.authenticate(req).catch(() => null);
    if (!userId) return errorResponse(401, "unauthorized");

    const body = await req.json().catch(() => null);
    if (!isUuid(body?.resume_id)) return errorResponse(400, "invalid_request", "resume_id must be a UUID");

    try {
      return json(await parseResume(deps.build(userId), { resumeId: body.resume_id, userId }));
    } catch (e) {
      if (e instanceof ParseRequestError) return errorResponse(e.httpStatus, e.code);
      console.error(JSON.stringify({ fn: "parse-resume", msg: "unhandled", error: String(e) }));
      if (e instanceof LlmConfigError) return errorResponse(500, "config_error", "LLM provider is misconfigured");
      return errorResponse(500, "internal");
    }
  };
}

function productionDeps(): HandlerDeps {
  return {
    authenticate: userIdFrom,
    build(userId) {
      const admin = adminClient();
      return {
        repo: new SupabaseResumeRepo(admin),
        index: new SupabaseSkillIndex(admin as unknown as SkillDb),
        llm: getMeteredProvider({
          functionName: "parse-resume",
          userId,
          store: new SupabaseUsageStore(admin as unknown as UsageDb),
        }),
      };
    },
  };
}

if (import.meta.main) Deno.serve(createHandler(productionDeps()));
