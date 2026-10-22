// Local-only integration: real Auth, PostgREST, Storage, Edge and Realtime.
import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.117.2";
function check(ok: unknown, message: string): asserts ok {
  if (!ok) throw new Error(message);
}
const cli = Deno.env.get("SUPABASE_CLI") ?? "supabase";
const output = await new Deno.Command(cli, {
  args: ["status", "-o", "json"],
  stdout: "piped",
  stderr: "piped",
})
  .output();
check(output.success, "local status failed");
const config = JSON.parse(new TextDecoder().decode(output.stdout));
const base = config.API_URL;
check(
  ["localhost", "127.0.0.1", "[::1]"].includes(new URL(base).hostname),
  "local endpoint required",
);
const options = { auth: { persistSession: false, autoRefreshToken: false } };
const admin = createClient(base, config.SERVICE_ROLE_KEY, options);
const users: string[] = [];
const clients: SupabaseClient[] = [];
let application: string | undefined;
let uploaded: string[] = [];
async function signup(role: string) {
  const client = createClient(base, config.ANON_KEY, options);
  clients.push(client);
  const email = `privacy-${crypto.randomUUID()}@example.test`;
  const { data, error } = await client.auth.signUp({
    email,
    password: crypto.randomUUID() + "Z9!",
    options: { data: { role } },
  });
  check(!error && data.session && data.user, "signup failed");
  users.push(data.user.id);
  return { client, id: data.user.id, token: data.session.access_token };
}
async function rpc(
  client: SupabaseClient,
  name: string,
  body: Record<string, unknown> = {},
) {
  const { data, error } = await client.rpc(name, body);
  check(!error, `RPC failed: ${name} ${error?.message}`);
  return data;
}
async function edge(name: string, token?: string, body: unknown = {}) {
  const response = await fetch(`${base}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      apikey: config.ANON_KEY,
      Authorization: `Bearer ${token ?? config.ANON_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const data = await response.json();
  return { status: response.status, data };
}
async function subscribe(
  client: SupabaseClient,
  table: string,
  onChange: (row: Record<string, unknown>) => void,
) {
  const channel = client.channel(`privacy-${crypto.randomUUID()}`).on(
    "postgres_changes",
    { event: "UPDATE", schema: "public", table },
    (payload) => onChange(payload.new),
  );
  await new Promise<void>((resolve, reject) => {
    // Channel join can succeed before the database replication subscription is
    // installed, especially just after reset. Wait for PostgreSQL's own ack too.
    let joined = false, databaseReady = false;
    const timer = setTimeout(
      () => reject(new Error(`subscription timeout: ${table}`)),
      30000,
    );
    const ready = () => {
      if (joined && databaseReady) {
        clearTimeout(timer);
        resolve();
      }
    };
    channel.on("system", {}, (message) => {
      if (message.status === "ok") {
        databaseReady = true;
        ready();
      }
      if (message.status === "error") {
        clearTimeout(timer);
        reject(new Error(`database subscription failed: ${table}`));
      }
    });
    channel.subscribe((status) => {
      if (status === "SUBSCRIBED") {
        joined = true;
        ready();
      }
      if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") {
        clearTimeout(timer);
        reject(new Error(`subscription failed: ${table}`));
      }
    });
  });
}
async function waitFor(test: () => boolean, message: string) {
  for (let i = 0; i < 100; i++) {
    if (test()) return;
    await new Promise((r) => setTimeout(r, 100));
  }
  check(false, message);
}
Deno.test({
  name:
    "real secure resume links, isolated live updates and complete account deletion",
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    try {
      const recruiter = await signup("recruiter"),
        candidate = await signup("candidate"),
        other = await signup("candidate"),
        outsider = await signup("recruiter");
      const company = (await rpc(recruiter.client, "create_company", {
        p_name: "Privacy Integration",
      })).id;
      await rpc(outsider.client, "create_company", {
        p_name: "Other Privacy Company",
      });
      const job = crypto.randomUUID(), resume = crypto.randomUUID();
      check(
        !(await recruiter.client.from("jobs").insert({
          id: job,
          company_id: company,
          created_by: recruiter.id,
          title: "Privacy Test",
          raw_description: "Synthetic role",
        })).error,
        "job insert failed",
      );
      const skill = (await recruiter.client.from("skills").select("id").eq(
        "name",
        "Flutter",
      ).single()).data!.id;
      await rpc(recruiter.client, "save_requirements", {
        p_job_id: job,
        p_requirements: [{
          skill_id: skill,
          required: true,
          min_years: 1,
          weight: 2,
        }],
      });
      await rpc(recruiter.client, "set_job_status", {
        p_job_id: job,
        p_status: "OPEN",
      });
      const path = `${candidate.id}/${resume}.pdf`;
      const bytes = new TextEncoder().encode(
        "%PDF-1.4\nSynthetic private resume\n%%EOF",
      );
      const upload = await candidate.client.storage.from("resumes").upload(
        path,
        bytes,
        {
          contentType: "application/pdf",
        },
      );
      check(!upload.error, "resume upload failed");
      uploaded.push(path);
      // More than one Storage page, including files without resume metadata.
      for (let batch = 0; batch < 5; batch++) {
        await Promise.all(Array.from({ length: 21 }, async () => {
          const extra = `${candidate.id}/${crypto.randomUUID()}.pdf`;
          const result = await candidate.client.storage.from("resumes").upload(
            extra,
            bytes,
            {
              contentType: "application/pdf",
            },
          );
          check(!result.error, "pagination fixture upload failed");
          uploaded.push(extra);
        }));
      }
      // Include a file without a resumes row to ensure cleanup covers the whole folder.
      const orphan = `${candidate.id}/${crypto.randomUUID()}.pdf`;
      check(
        !(await candidate.client.storage.from("resumes").upload(orphan, bytes, {
          contentType: "application/pdf",
        }))
          .error,
        "orphan upload failed",
      );
      uploaded.push(orphan);
      check(
        !(await candidate.client.from("resumes").insert({
          id: resume,
          candidate_id: candidate.id,
          storage_path: path,
          file_hash: "synthetic",
          mime_type: "application/pdf",
        })).error,
        "resume row failed",
      );
      const version = (await rpc(candidate.client, "create_manual_profile")).id;
      check(
        !(await admin.from("profile_versions").update({
          resume_id: resume,
          source: "resume",
        }).eq("id", version)).error,
        "fixture resume link failed",
      );
      await rpc(candidate.client, "confirm_profile", {
        p_version_id: version,
        p_skills: [{
          skill_id: skill,
          raw_name: "Flutter",
          years: 3,
          evidence: "Synthetic evidence",
        }],
      });
      application = (await rpc(candidate.client, "swipe", {
        p_job_id: job,
        p_direction: "right",
      })).application_id;
      check(
        (await edge("resume-url", undefined, { application_id: application }))
          .status === 401,
        "anonymous link accepted",
      );
      check(
        (await edge("resume-url", candidate.token, {
          application_id: application,
        })).status === 403,
        "candidate recruiter link accepted",
      );
      check(
        (await edge("resume-url", outsider.token, {
          application_id: application,
        })).status === 404,
        "cross-company link accepted",
      );
      check(
        (await edge("resume-url", recruiter.token, {
          application_id: application,
        })).status === 404,
        "pending link accepted",
      );
      check(
        !(await admin.from("applications").update({
          committed_at: new Date(Date.now() - 1000).toISOString(),
        }).eq(
          "id",
          application,
        )).error,
        "deadline fixture failed",
      );
      check(
        (await edge("resume-url", recruiter.token, {
          application_id: application,
        })).status === 404,
        "unadvanced link accepted",
      );
      const ownEvents: Record<string, unknown>[] = [],
        otherEvents: Record<string, unknown>[] = [],
        resumeEvents: Record<string, unknown>[] = [],
        otherResumes: Record<string, unknown>[] = [],
        jobEvents: Record<string, unknown>[] = [],
        otherJobs: Record<string, unknown>[] = [];
      await subscribe(
        candidate.client,
        "applications",
        (row) => ownEvents.push(row),
      );
      await subscribe(
        other.client,
        "applications",
        (row) => otherEvents.push(row),
      );
      await subscribe(
        candidate.client,
        "resumes",
        (row) => resumeEvents.push(row),
      );
      await subscribe(other.client, "resumes", (row) => otherResumes.push(row));
      await subscribe(recruiter.client, "jobs", (row) => jobEvents.push(row));
      await subscribe(outsider.client, "jobs", (row) => otherJobs.push(row));
      check(
        !(await admin.from("jobs").update({ title: "Updated Privacy Test" }).eq(
          "id",
          job,
        )).error,
        "job update failed",
      );
      await rpc(recruiter.client, "advance", {
        p_application_id: application,
        p_note: "Synthetic note",
      });
      check(
        !(await admin.from("resumes").update({ status: "PARSING_LAYOUT" }).eq(
          "id",
          resume,
        )).error,
        "parse update failed",
      );
      await waitFor(
        () =>
          ownEvents.some((x) =>
            x.id === application && x.status === "INTERVIEW_REQUESTED"
          ),
        "own application live event missing",
      );
      await waitFor(
        () =>
          resumeEvents.some((x) =>
            x.id === resume && x.status === "PARSING_LAYOUT"
          ),
        "own resume live event missing",
      );
      await waitFor(
        () => jobEvents.some((x) => x.id === job),
        "own company job live event missing",
      );
      await new Promise((r) => setTimeout(r, 1000));
      check(
        !otherEvents.some((x) => x.id === application),
        "application event leaked to another candidate",
      );
      check(
        !otherResumes.some((x) => x.id === resume),
        "resume parse event leaked to another candidate",
      );
      check(
        !otherJobs.some((x) => x.id === job),
        "job event leaked to another company",
      );
      const signed = await edge("resume-url", recruiter.token, {
        application_id: application,
      });
      check(
        signed.status === 200 && signed.data.url,
        "advanced signed link missing",
      );
      // URL must be usable by the app without host rewriting.
      const download = await fetch(signed.data.url);
      check(
        download.ok &&
          (await download.text()).includes("Synthetic private resume"),
        "signed resume could not download",
      );
      console.log(
        "PASS: real signed resume and isolated application/parse Realtime clients",
      );
      check(
        (await edge("delete-account", recruiter.token)).status === 403,
        "recruiter deletion accepted",
      );
      await rpc(recruiter.client, "reject", {
        p_application_id: application,
        p_reason: "Synthetic private rejection text",
      });
      check(
        (await edge("resume-url", recruiter.token, {
          application_id: application,
        })).status === 404,
        "rejected application issued new signed URL",
      );
      // Simulate retry after a failure between SQL preparation and Storage removal.
      await rpc(candidate.client, "prepare_account_deletion");
      const lateUpload = await candidate.client.storage.from("resumes").upload(
        `${candidate.id}/${crypto.randomUUID()}.pdf`,
        bytes,
        { contentType: "application/pdf" },
      );
      check(lateUpload.error, "new upload permitted during deletion");
      const deleted = await edge("delete-account", candidate.token, {
        user_id: other.id,
      });
      check(
        deleted.status === 200 && deleted.data.deleted,
        "account deletion failed",
      );
      uploaded = [];
      for (
        const [table, column] of [
          ["profiles", "id"],
          ["candidates", "profile_id"],
          ["resumes", "candidate_id"],
          ["profile_versions", "candidate_id"],
          ["swipes", "candidate_id"],
          ["device_tokens", "user_id"],
          ["llm_usage", "user_id"],
        ]
      ) {
        const result = await admin.from(table).select("*", {
          count: "exact",
          head: true,
        }).eq(column, candidate.id);
        check(
          !result.error && result.count === 0,
          `remaining private rows: ${table}`,
        );
      }
      check(
        (await admin.from("candidate_skills").select("id").eq(
          "profile_version_id",
          version,
        )).data?.length === 0,
        "skill evidence remains",
      );
      const remaining = await admin.from("applications").select("*").eq(
        "id",
        application,
      ).single();
      check(
        !remaining.error && remaining.data.anonymized &&
          remaining.data.candidate_id === null &&
          remaining.data.profile_version_id === null &&
          remaining.data.swipe_id === null &&
          remaining.data.interview_note === null &&
          remaining.data.breakdown.length === 0,
        "retained application not anonymized",
      );
      check(
        (await admin.from("application_reject_reasons").select("application_id")
          .eq("application_id", application)).data
          ?.length === 0,
        "private rejection text remains",
      );
      check(
        (await admin.from("status_events").select("id").eq(
          "actor_id",
          candidate.id,
        )).data?.length === 0,
        "identifiable audit actor remains",
      );
      check(
        (await admin.storage.from("resumes").list(candidate.id)).data
          ?.length === 0,
        "private files remain",
      );
      check(
        (await admin.auth.admin.getUserById(candidate.id)).error,
        "Auth user remains",
      );
      check(
        !(await other.client.auth.getUser()).error,
        "body-selected victim was deleted",
      );
      const stale = await fetch(signed.data.url);
      check(!stale.ok, "old signed URL still serves deleted file");
      await stale.body?.cancel();
      check(
        (await rpc(recruiter.client, "get_board", { p_job_id: job })).length ===
          0,
        "deleted candidate remains on board",
      );
      console.log(
        "PASS: retryable deletion removes Auth, Storage and private rows while retaining anonymized application",
      );
    } finally {
      for (const client of clients) {
        await client.removeAllChannels();
        client.realtime.disconnect();
      }
      if (uploaded.length) await admin.storage.from("resumes").remove(uploaded);
      if (application) {
        await admin.from("applications").delete().eq("id", application);
      }
      // Delete all synthetic companies before auth owners; never touch seed/team rows.
      for (const user of users) {
        await admin.from("companies").delete().eq("created_by", user);
      }
      for (const user of users) await admin.auth.admin.deleteUser(user);
      admin.realtime.disconnect();
    }
  },
});
