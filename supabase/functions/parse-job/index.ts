// parse-job Edge Function (B7 / AI-12). Contract: docs/API_CONTRACT.md §3.
//   POST { "job_id": uuid }  with a recruiter's JWT
//   → 200 { parse_status: "READY", job, requirements, unmapped, trimmed } | 200 { parse_status: "FAILED", failure_reason }
//   → 400 invalid_request · 401 unauthorized · 403 not_company_recruiter · 404 job_not_found · 409 job_not_draft
import { CORS_HEADERS, errorResponse, isUuid, json } from "../_shared/http.ts";
import { type JobParseDeps, JobRequestError, parseJob } from "../_shared/job_pipeline.ts";
import { SupabaseJobRepo } from "../_shared/job_repo.ts";
import { LlmConfigError } from "../_shared/llm.ts";
import { type SkillDb, SupabaseSkillIndex } from "../_shared/normalize.ts";
import { adminClient, userIdFrom } from "../_shared/supabase.ts";
import { getMeteredProvider, SupabaseUsageStore, type UsageDb } from "../_shared/usage.ts";

export interface HandlerDeps {
  authenticate(req: Request): Promise<string | null>;
  build(userId: string): JobParseDeps;
}

export function createHandler(deps: HandlerDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
    if (req.method !== "POST") return errorResponse(405, "method_not_allowed");

    const userId = await deps.authenticate(req).catch(() => null);
    if (!userId) return errorResponse(401, "unauthorized");

    const body = await req.json().catch(() => null);
    if (!isUuid(body?.job_id)) return errorResponse(400, "invalid_request", "job_id must be a UUID");

    try {
      return json(await parseJob(deps.build(userId), { jobId: body.job_id, userId }));
    } catch (e) {
      if (e instanceof JobRequestError) return errorResponse(e.httpStatus, e.code);
      console.error(JSON.stringify({ fn: "parse-job", msg: "unhandled", error: String(e) }));
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
        repo: new SupabaseJobRepo(admin),
        index: new SupabaseSkillIndex(admin as unknown as SkillDb),
        llm: getMeteredProvider({
          functionName: "parse-job",
          userId,
          store: new SupabaseUsageStore(admin as unknown as UsageDb),
        }),
      };
    },
  };
}

if (import.meta.main) Deno.serve(createHandler(productionDeps()));
