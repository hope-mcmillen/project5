import { assertEquals } from "jsr:@std/assert@1.0.13";
import { MockProvider } from "../_shared/llm.ts";
import { MemoryResumeRepo } from "../_shared/resume_repo_memory.ts";
import { seedSkillIndex } from "../_shared/seed_taxonomy.ts";
import { createHandler } from "./index.ts";

const ALICE = "11111111-1111-4111-8111-111111111111";
const RESUME = "33333333-3333-4333-8333-333333333333";
const index = await seedSkillIndex();

async function handler() {
  const repo = new MemoryResumeRepo();
  repo.add(
    { id: RESUME, candidate_id: ALICE },
    await Deno.readFile(new URL("../../seed/resumes/r04_devops_single_column.pdf", import.meta.url)),
  );
  return createHandler({
    authenticate: (req) => Promise.resolve(req.headers.get("Authorization") === "Bearer alice" ? ALICE : null),
    build: () => ({ repo, llm: new MockProvider(), index, log: () => {} }),
  });
}

const post = (body: unknown, auth = "Bearer alice") =>
  new Request("http://localhost/parse-resume", {
    method: "POST",
    headers: { Authorization: auth, "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });

const errorCode = async (res: Response) => (await res.json()).error.code;

Deno.test("CORS preflight and method check", async () => {
  const h = await handler();
  const pre = await h(new Request("http://localhost/parse-resume", { method: "OPTIONS" }));
  assertEquals([pre.status, pre.headers.get("Access-Control-Allow-Origin")], [200, "*"]);
  const get = await h(new Request("http://localhost/parse-resume"));
  assertEquals([get.status, await errorCode(get)], [405, "method_not_allowed"]);
});

Deno.test("401 without a valid JWT, 400 for a bad body", async () => {
  const h = await handler();
  const noAuth = await h(post({ resume_id: RESUME }, "Bearer someone-else"));
  assertEquals([noAuth.status, await errorCode(noAuth)], [401, "unauthorized"]);
  for (const bad of ["not json", {}, { resume_id: "123" }]) {
    const res = await h(post(bad));
    assertEquals([res.status, await errorCode(res)], [400, "invalid_request"]);
  }
});

Deno.test("404 for an unknown resume", async () => {
  const res = await (await handler())(post({ resume_id: crypto.randomUUID() }));
  assertEquals([res.status, await errorCode(res)], [404, "resume_not_found"]);
});

Deno.test("200 with the contract's READY shape, then 200 cached on repeat", async () => {
  const h = await handler();
  const res = await h(post({ resume_id: RESUME }));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(Object.keys(body).sort(), [
    "cached",
    "profile_version_id",
    "resume_id",
    "skill_count",
    "status",
    "unmapped_count",
    "version",
  ]);
  assertEquals([body.status, body.cached, body.version], ["READY", false, 1]);
  const again = await (await h(post({ resume_id: RESUME }))).json();
  assertEquals({ ...again, cached: false }, body);
});
