import { assert, assertAlmostEquals, assertEquals, assertRejects } from "jsr:@std/assert@1.0.13";
import { EMBEDDING_MODEL_TAG } from "./gemini.ts";
import { EMBED_DIMS, type EmbedResult } from "./llm.ts";
import {
  MATCH_THRESHOLD,
  MemorySkillIndex,
  normalizeSkills,
  type SkillDb,
  skillEmbedText,
  SupabaseSkillIndex,
  type TaxonomySkill,
} from "./normalize.ts";
import { loadSeedEmbeddings, loadSeedRelations, loadSeedSkills, seedSkillIndex } from "./seed_taxonomy.ts";

const SEED = new URL("../../seed/", import.meta.url);

// A 3-dim toy taxonomy so similarities are easy to reason about.
const TAXONOMY: TaxonomySkill[] = [
  { id: "react", name: "React", category: "Frameworks", aliases: ["reactjs", "react.js"] },
  { id: "pg", name: "PostgreSQL", category: "Data", aliases: ["postgres"] },
  { id: "k8s", name: "Kubernetes", category: "Cloud/DevOps", aliases: ["k8s"] },
];
const unit = (v: number[]) => v.map((x) => x / Math.hypot(...v));
const VECTORS = new Map([["react", unit([1, 0, 0])], ["pg", unit([0, 1, 0])], ["k8s", unit([0, 0, 1])]]);
const QUERY_VECTORS: Record<string, number[]> = {
  "React Hooks": unit([1, 0.2, 0]), // cos ≈ 0.98 to React
  "Postgres DB": unit([0.1, 1, 0.1]), // cos ≈ 0.99 to PostgreSQL
  "Photoshop": unit([1, 1, 1]), // cos ≈ 0.58 to everything
};

function fakeEmbedder() {
  const calls: string[][] = [];
  return {
    calls,
    embed: (texts: string[]): Promise<EmbedResult> => {
      calls.push(texts);
      return Promise.resolve({
        vectors: texts.map((t) => QUERY_VECTORS[t]),
        usage: { inputTokens: 1, outputTokens: 0 },
        provider: "mock",
        model: "test",
      });
    },
  };
}

Deno.test("normalizeSkills: exact, alias, embedding, and unmapped, with one batched embed call", async () => {
  const llm = fakeEmbedder();
  const res = await normalizeSkills(
    ["react", " ReactJS ", "React Hooks", "Postgres DB", "Photoshop", "KUBERNETES"],
    llm,
    new MemorySkillIndex(TAXONOMY, VECTORS),
  );
  assertEquals(res.map((r) => [r.name, r.via]), [
    ["React", "exact"],
    ["React", "alias"],
    ["React", "embedding"],
    ["PostgreSQL", "embedding"],
    [null, "unmapped"],
    ["Kubernetes", "exact"],
  ]);
  assertEquals(llm.calls, [["React Hooks", "Postgres DB", "Photoshop"]]); // only the misses, in one call
  assertEquals(res[2].category, "Frameworks");
  assert(res[2].similarity! > MATCH_THRESHOLD);
  assertAlmostEquals(res[4].similarity!, 0.577, 0.001); // unmapped still reports how close it came
  assertEquals(res[4].skill_id, null);
});

Deno.test("normalizeSkills: no embed call when everything matches exactly; threshold is configurable", async () => {
  const llm = fakeEmbedder();
  await normalizeSkills(["React", "postgres"], llm, new MemorySkillIndex(TAXONOMY, VECTORS));
  assertEquals(llm.calls.length, 0);
  const loose = await normalizeSkills(["Photoshop"], fakeEmbedder(), new MemorySkillIndex(TAXONOMY, VECTORS), {
    threshold: 0.5,
  });
  assertEquals(loose[0].via, "embedding");
});

Deno.test("SupabaseSkillIndex caches the taxonomy and calls match_skills with the RPC's parameter names", async () => {
  let selects = 0;
  const rpcArgs: unknown[] = [];
  const db: SkillDb = {
    from: () => ({
      select: () => (selects++, Promise.resolve({ data: TAXONOMY, error: null })),
    }),
    rpc: (_fn, args) => {
      rpcArgs.push(args);
      return Promise.resolve({ data: [{ skill_id: "react", name: "React", similarity: 0.97 }], error: null });
    },
  };
  const index = new SupabaseSkillIndex(db);
  await index.skills();
  await index.skills();
  assertEquals(selects, 1);
  assertEquals(await index.nearest([1, 0, 0], 0.89, 3), [{ skill_id: "react", name: "React", similarity: 0.97 }]);
  assertEquals(rpcArgs, [{ p_embedding: [1, 0, 0], p_threshold: 0.89, p_k: 3 }]);

  const failing = new SupabaseSkillIndex({
    from: () => ({ select: () => Promise.resolve({ data: null, error: { message: "boom" } }) }),
    rpc: () => Promise.resolve({ data: null, error: { message: "no function" } }),
  });
  await assertRejects(() => failing.skills(), Error, "skills read failed");
  await assertRejects(() => failing.nearest([1], 0.89, 1), Error, "match_skills failed");
});

Deno.test("skillEmbedText is name: aliases", () => {
  assertEquals(skillEmbedText("React", ["reactjs", "react.js"]), "React: reactjs, react.js");
  assertEquals(skillEmbedText("Go", []), "Go");
});

Deno.test("seed embeddings cover every skill with unit 1536-dim vectors from the pinned model", async () => {
  const skills = await loadSeedSkills();
  const { model, vectors } = await loadSeedEmbeddings();
  assertEquals(model, EMBEDDING_MODEL_TAG);
  assertEquals([...vectors.keys()].sort(), skills.map((s) => s.name).sort(), "re-run deno task embed:taxonomy");
  for (const [name, v] of vectors) {
    assertEquals(v.length, EMBED_DIMS, name);
    assertAlmostEquals(Math.hypot(...v), 1, 1e-4, name);
  }
});

Deno.test("skills.sql is in sync with the CSVs", async () => {
  const sql = await Deno.readTextFile(new URL("skills.sql", SEED));
  const q = (s: string) => `'${s.replaceAll("'", "''")}'`;
  for (const s of await loadSeedSkills()) assert(sql.includes(`(${q(s.name)}, ${q(s.category)}, array[`), s.name);
  for (const r of await loadSeedRelations()) {
    assert(sql.includes(`(${q(r.skill)}, ${q(r.related)}, ${r.credit})`), `${r.skill} -> ${r.related}`);
  }
});

Deno.test("seed index: every name and alias maps to its own skill with no AI call", async () => {
  const index = await seedSkillIndex();
  const skills = await index.skills();
  const raws = skills.flatMap((s) => [s.name, ...s.aliases]);
  const noEmbed = { embed: () => Promise.reject(new Error("should not embed")) };
  const res = await normalizeSkills(raws, noEmbed, index);
  const owner = new Map(skills.flatMap((s) => [s.name, ...s.aliases].map((r) => [r, s.name] as const)));
  for (const r of res) assertEquals(r.name, owner.get(r.raw), r.raw);
});

Deno.test("seed index: a stored skill vector is its own nearest neighbor", async () => {
  const index = await seedSkillIndex();
  const { vectors } = await loadSeedEmbeddings();
  for (const name of ["React", "PostgreSQL", "Kubernetes", "C", "C#", "Go"]) {
    const [best] = await index.nearest(vectors.get(name)!, MATCH_THRESHOLD, 3);
    assertEquals(best.name, name);
    assertAlmostEquals(best.similarity, 1, 1e-4);
  }
});
