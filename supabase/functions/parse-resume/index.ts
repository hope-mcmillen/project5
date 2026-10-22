// parse-resume Edge Function (B6 / AI-07). Contract: docs/API_CONTRACT.md §2.
//   POST multipart/form-data { file: <PDF or DOCX, ≤ 5 MB> }  with the candidate's JWT
//   The file is read in memory and never stored.
//
//   Accept: application/json (default)
//     → 200 { status: "READY", ... } | 200 { status: "FAILED", failure_reason }
//   Accept: text/event-stream
//     → 200, one `data: {"status": "<step>"}` event per step, then the same final body as above
//
//   → 400 invalid_request | invalid_file · 401 unauthorized · 403 not_candidate
import { CORS_HEADERS, errorResponse, json } from "../_shared/http.ts";
import { LlmConfigError } from "../_shared/llm.ts";
import { type SkillDb, SupabaseSkillIndex } from "../_shared/normalize.ts";
import { SupabaseProfileStore } from "../_shared/profile_store.ts";
import {
  type AgentDeps,
  checkUpload,
  DEFAULT_REPAIR_ROUNDS,
  MAX_FILE_BYTES,
  ParseRequestError,
  parseResume,
  type ResumeUpload,
} from "../_shared/resume_agent.ts";
import { adminClient, userIdFrom } from "../_shared/supabase.ts";
import { getMeteredProvider, SupabaseUsageStore, type UsageDb } from "../_shared/usage.ts";

export interface HandlerDeps {
  authenticate(req: Request): Promise<string | null>;
  build(userId: string): AgentDeps;
}

export function createHandler(deps: HandlerDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
    if (req.method !== "POST") return errorResponse(405, "method_not_allowed");

    const userId = await deps.authenticate(req).catch(() => null);
    if (!userId) return errorResponse(401, "unauthorized");

    const upload = await readUpload(req, userId);
    if (!upload) return errorResponse(400, "invalid_request", 'Send the resume as multipart field "file"');

    try {
      const agentDeps = deps.build(userId);
      await checkUpload(agentDeps, upload);
      if (req.headers.get("Accept")?.includes("text/event-stream")) return stream(agentDeps, upload);
      return json(await parseResume(agentDeps, upload));
    } catch (e) {
      return failure(e);
    }
  };
}

async function readUpload(req: Request, userId: string): Promise<ResumeUpload | null> {
  // Reject oversized bodies before buffering them (multipart adds a little overhead).
  const length = Number(req.headers.get("Content-Length") ?? 0);
  if (length > MAX_FILE_BYTES + 64 * 1024) return null;
  const form = await req.formData().catch(() => null);
  const file = form?.get("file");
  if (!(file instanceof File)) return null;
  return { userId, filename: file.name, bytes: new Uint8Array(await file.arrayBuffer()) };
}

/** Server-sent events: each step as it starts, then the final result. */
function stream(deps: AgentDeps, upload: ResumeUpload): Response {
  const encoder = new TextEncoder();
  const body = new ReadableStream<Uint8Array>({
    async start(controller) {
      const send = (event: unknown) => {
        try {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
        } catch {
          // The client went away; the parse still finishes and saves.
        }
      };
      try {
        send(await parseResume({ ...deps, onStep: (status) => send({ status }) }, upload));
      } catch (e) {
        console.error(JSON.stringify({ fn: "parse-resume", msg: "unhandled", error: String(e) }));
        send({ status: "FAILED", failure_reason: "internal" });
      }
      try {
        controller.close();
      } catch {
        // Already closed by a disconnect.
      }
    },
  });
  return new Response(body, {
    headers: { ...CORS_HEADERS, "Content-Type": "text/event-stream", "Cache-Control": "no-cache" },
  });
}

function failure(e: unknown): Response {
  if (e instanceof ParseRequestError) return errorResponse(e.httpStatus, e.code);
  console.error(JSON.stringify({ fn: "parse-resume", msg: "unhandled", error: String(e) }));
  if (e instanceof LlmConfigError) return errorResponse(500, "config_error", "LLM provider is misconfigured");
  return errorResponse(500, "internal");
}

function productionDeps(): HandlerDeps {
  const rounds = Number(Deno.env.get("RESUME_REPAIR_ROUNDS") ?? DEFAULT_REPAIR_ROUNDS);
  return {
    authenticate: userIdFrom,
    build(userId) {
      const admin = adminClient();
      return {
        store: new SupabaseProfileStore(admin),
        index: new SupabaseSkillIndex(admin as unknown as SkillDb),
        llm: getMeteredProvider({
          functionName: "parse-resume",
          userId,
          store: new SupabaseUsageStore(admin as unknown as UsageDb),
        }),
        maxRepairRounds: Number.isInteger(rounds) && rounds >= 0 ? Math.min(rounds, 3) : DEFAULT_REPAIR_ROUNDS,
      };
    },
  };
}

if (import.meta.main) Deno.serve(createHandler(productionDeps()));
