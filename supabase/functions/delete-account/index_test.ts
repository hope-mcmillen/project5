// deno-lint-ignore-file require-await -- synchronous dependency doubles implement async interfaces.
import { createHandler, type Deps } from "./index.ts";
import { EndpointError } from "../resume-url/runtime.ts";
function check(ok: boolean) {
  if (!ok) throw new Error("assertion failed");
}
const request = () =>
  new Request("http://localhost/delete-account", { method: "POST", body: JSON.stringify({ user_id: "victim" }) });
Deno.test("deletion always uses JWT identity and removes Auth last", async () => {
  const calls: string[] = [];
  const response = await createHandler({
    authenticate: async () => "caller",
    prepare: async () => {
      calls.push("prepare");
    },
    removeFiles: async (user) => {
      calls.push("files:" + user);
    },
    removeUser: async (user) => {
      calls.push("auth:" + user);
    },
  })(request());
  check(response.status === 200 && (await response.json()).deleted);
  check(calls.join(",") === "prepare,files:caller,auth:caller");
});
Deno.test("failed preparation or storage cleanup never deletes Auth; failures are explicit", async () => {
  for (const stage of ["prepare", "files"]) {
    const calls: string[] = [];
    const response = await createHandler({
      authenticate: async () => "caller",
      prepare: async () => {
        calls.push("prepare");
        if (stage === "prepare") throw new EndpointError(403, "not_candidate");
      },
      removeFiles: async () => {
        calls.push("files");
        throw new Error("private error");
      },
      removeUser: async () => {
        calls.push("auth");
      },
    })(request());
    check(response.status === (stage === "prepare" ? 403 : 500) && !calls.includes("auth"));
  }
});
Deno.test("missing JWT cannot trigger deletion and auth errors remain retryable", async () => {
  const no = async () => {
    throw new Error("must not call");
  };
  const deps: Deps = { authenticate: async () => null, prepare: no, removeFiles: no, removeUser: no };
  check((await createHandler(deps)(request())).status === 401);
  check(
    (await createHandler({
      ...deps,
      authenticate: async () => "caller",
      prepare: async () => {},
      removeFiles: async () => {},
    })(request())).status === 500,
  );
});
