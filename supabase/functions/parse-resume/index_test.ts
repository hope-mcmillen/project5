import { assertEquals } from "jsr:@std/assert@1.0.13";
import { MockProvider } from "../_shared/llm.ts";
import { MemoryProfileStore } from "../_shared/profile_store.ts";
import { seedSkillIndex } from "../_shared/seed_taxonomy.ts";
import { createHandler } from "./index.ts";

const ALICE = "11111111-1111-4111-8111-111111111111";
const BOB = "22222222-2222-4222-8222-222222222222";
const index = await seedSkillIndex();
const RESUME = await Deno.readFile(new URL("../../seed/resumes/r04_devops_single_column.pdf", import.meta.url));

function handler() {
  const store = new MemoryProfileStore(new Set([ALICE]));
  const users: Record<string, string> = { "Bearer alice": ALICE, "Bearer bob": BOB };
  const h = createHandler({
    authenticate: (req) => Promise.resolve(users[req.headers.get("Authorization") ?? ""] ?? null),
    build: () => ({ store, llm: new MockProvider(), index, log: () => {} }),
  });
  return { h, store };
}

function post(file: Uint8Array | null, opts: { auth?: string; name?: string; accept?: string } = {}) {
  const form = new FormData();
  if (file) form.append("file", new File([file as Uint8Array<ArrayBuffer>], opts.name ?? "resume.pdf"));
  return new Request("http://localhost/parse-resume", {
    method: "POST",
    headers: { Authorization: opts.auth ?? "Bearer alice", ...(opts.accept ? { Accept: opts.accept } : {}) },
    body: form,
  });
}

const errorCode = async (res: Response) => (await res.json()).error.code;

Deno.test("CORS preflight and method check", async () => {
  const { h } = handler();
  const pre = await h(new Request("http://localhost/parse-resume", { method: "OPTIONS" }));
  assertEquals([pre.status, pre.headers.get("Access-Control-Allow-Origin")], [200, "*"]);
  const get = await h(new Request("http://localhost/parse-resume"));
  assertEquals([get.status, await errorCode(get)], [405, "method_not_allowed"]);
});

Deno.test("401 without a valid JWT, 400 without a file or with a bad one, 403 for non-candidates", async () => {
  const { h, store } = handler();
  const noAuth = await h(post(RESUME, { auth: "Bearer someone-else" }));
  assertEquals([noAuth.status, await errorCode(noAuth)], [401, "unauthorized"]);
  const noFile = await h(post(null));
  assertEquals([noFile.status, await errorCode(noFile)], [400, "invalid_request"]);
  const json = await h(
    new Request("http://localhost/parse-resume", {
      method: "POST",
      headers: { Authorization: "Bearer alice", "Content-Type": "application/json" },
      body: JSON.stringify({ resume_id: crypto.randomUUID() }),
    }),
  );
  assertEquals([json.status, await errorCode(json)], [400, "invalid_request"]);
  const text = await h(post(new TextEncoder().encode("hello"), { name: "resume.pdf" }));
  assertEquals([text.status, await errorCode(text)], [400, "invalid_file"]);
  const bob = await h(post(RESUME, { auth: "Bearer bob" }));
  assertEquals([bob.status, await errorCode(bob)], [403, "not_candidate"]);
  assertEquals(store.versions.length, 0);
});

Deno.test("200 with the contract's READY shape; each upload is a new version", async () => {
  const { h, store } = handler();
  const res = await h(post(RESUME));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(Object.keys(body).sort(), [
    "experience_count",
    "profile_version_id",
    "repair_rounds",
    "skill_count",
    "status",
    "unmapped_count",
    "version",
  ]);
  assertEquals([body.status, body.version, body.profile_version_id], ["READY", 1, store.versions[0].id]);
  const again = await (await h(post(RESUME))).json();
  assertEquals(again.version, 2);
});

Deno.test("Accept: text/event-stream streams each step, then the result", async () => {
  const { h } = handler();
  const res = await h(post(RESUME, { accept: "text/event-stream" }));
  assertEquals([res.status, res.headers.get("Content-Type")], [200, "text/event-stream"]);
  const events = (await res.text()).split("\n\n").filter(Boolean).map((e) => JSON.parse(e.replace(/^data: /, "")));
  assertEquals(events.map((e) => e.status), ["PARSING_LAYOUT", "EXTRACTING", "NORMALIZING", "READY"]);
  assertEquals(events.at(-1).version, 1);
});
