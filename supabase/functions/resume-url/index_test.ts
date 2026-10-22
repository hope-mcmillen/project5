// deno-lint-ignore-file require-await -- synchronous dependency doubles implement async interfaces.
import { createHandler, type Deps } from "./index.ts";
import { EndpointError } from "./runtime.ts";
const id = "50000000-0000-0000-0000-000000000001";
function request(body: unknown = { application_id: id }, method = "POST") {
  return new Request("http://localhost/resume-url", {
    method,
    body: method === "POST" ? JSON.stringify(body) : undefined,
  });
}
function check(ok: boolean) {
  if (!ok) throw new Error("assertion failed");
}
function deps(overrides: Partial<Deps> = {}): Deps {
  return {
    authenticate: async () => "recruiter",
    path: async () => "candidate/file.pdf",
    sign: async () => "signed",
    ...overrides,
  };
}
Deno.test("resume URL signs only the authorized path for exactly 600 seconds", async () => {
  const response = await createHandler(deps({
    sign: async (path, seconds) => {
      check(path === "candidate/file.pdf" && seconds === 600);
      return "signed";
    },
  }))(request());
  check(response.status === 200 && (await response.json()).url === "signed");
});
Deno.test("resume URL rejects missing auth, invalid payload and methods", async () => {
  check((await createHandler(deps({ authenticate: async () => null }))(request())).status === 401);
  check((await createHandler(deps())(request({ application_id: "bad" }))).status === 400);
  check((await createHandler(deps())(request({}, "GET"))).status === 405);
  check((await createHandler(deps())(request({}, "OPTIONS"))).status === 200);
});
Deno.test("authorization and storage failures never issue a URL or leak details", async () => {
  for (const [status, code] of [[403, "not_recruiter"], [404, "not_owner"], [404, "resume_not_available"]] as const) {
    const response = await createHandler(deps({
      path: async () => {
        throw new EndpointError(status, code);
      },
      sign: async () => {
        throw new Error("must not sign");
      },
    }))(request());
    check(response.status === status && (await response.json()).error.code === code);
  }
  const response = await createHandler(deps({
    sign: async () => {
      throw new Error("secret storage error");
    },
  }))(request());
  check(response.status === 500 && !(await response.text()).includes("secret storage"));
});
