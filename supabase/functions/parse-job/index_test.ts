import { assertEquals } from "jsr:@std/assert@1.0.13";
import { MemoryJobRepo } from "../_shared/job_repo.ts";
import { MockProvider } from "../_shared/llm.ts";
import { seedSkillIndex } from "../_shared/seed_taxonomy.ts";
import { createHandler } from "./index.ts";

const JOB = "44444444-4444-4444-8444-444444444444";
const index = await seedSkillIndex();

async function handler() {
  const repo = new MemoryJobRepo();
  repo.recruiters.set("rec", "acme");
  repo.add({
    id: JOB,
    company_id: "acme",
    raw_description: await Deno.readTextFile(new URL("../../seed/jobs/job05_frontend_react.txt", import.meta.url)),
  });
  return createHandler({
    authenticate: (req) => Promise.resolve(req.headers.get("Authorization") === "Bearer rec" ? "rec" : null),
    build: () => ({ repo, llm: new MockProvider(), index, log: () => {} }),
  });
}
const post = (body: unknown, auth = "Bearer rec") =>
  new Request("http://localhost/parse-job", {
    method: "POST",
    headers: { Authorization: auth },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
const code = async (r: Response) => [r.status, (await r.json()).error.code];

Deno.test("parse-job HTTP errors", async () => {
  const h = await handler();
  assertEquals((await h(new Request("http://localhost/parse-job", { method: "OPTIONS" }))).status, 200);
  assertEquals(await code(await h(new Request("http://localhost/parse-job"))), [405, "method_not_allowed"]);
  assertEquals(await code(await h(post({ job_id: JOB }, "Bearer nope"))), [401, "unauthorized"]);
  assertEquals(await code(await h(post({ job_id: "x" }))), [400, "invalid_request"]);
  assertEquals(await code(await h(post({ job_id: crypto.randomUUID() }))), [404, "job_not_found"]);
});

Deno.test("parse-job 200 has the contract's READY shape", async () => {
  const res = await (await handler())(post({ job_id: JOB }));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(Object.keys(body).sort(), ["job", "job_id", "parse_status", "requirements", "trimmed", "unmapped"]);
  assertEquals(body.parse_status, "READY");
  assertEquals(Object.keys(body.requirements[0]).sort(), [
    "category",
    "either_of_group",
    "evidence",
    "id",
    "min_years",
    "name",
    "required",
    "skill_id",
    "weight",
  ]);
});
