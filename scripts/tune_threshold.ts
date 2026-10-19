// Tunes MATCH_THRESHOLD and the taxonomy embedding text (AI-10). From supabase/functions:
//   deno task tune:threshold
// Embeds every skill two ways ("name" vs "name: aliases") plus each query in
// supabase/tests/fixtures/alias_pairs.json, then reports accuracy per threshold.
// About 9 Gemini calls.
import { getProvider } from "../supabase/functions/_shared/llm.ts";
import {
  MemorySkillIndex,
  normalizeSkills,
  skillEmbedText,
} from "../supabase/functions/_shared/normalize.ts";
import { loadSeedSkills } from "../supabase/functions/_shared/seed_taxonomy.ts";

const pairs: Array<{ query: string; expect: string | null }> = JSON.parse(
  await Deno.readTextFile(
    new URL("../supabase/tests/fixtures/alias_pairs.json", import.meta.url),
  ),
).pairs;
const llm = getProvider((
  k,
) => (k === "LLM_PROVIDER" ? "gemini" : Deno.env.get(k)));
const skills = (await loadSeedSkills()).map((s) => ({ id: s.name, ...s }));

const variants: Record<string, (s: typeof skills[number]) => string> = {
  "name": (s) => s.name,
  "name: aliases (skillEmbedText, current)": (s) =>
    skillEmbedText(s.name, s.aliases),
};
const queryVecs = new Map(
  (await llm.embed(pairs.map((p) => p.query))).vectors.map((
    v,
    i,
  ) => [pairs[i].query, v]),
);
const cachedEmbed = {
  embed: (t: string[]) =>
    Promise.resolve({
      vectors: t.map((x) => queryVecs.get(x)!),
      usage: { inputTokens: 0, outputTokens: 0 },
      provider: "gemini" as const,
      model: "cached",
    }),
};

for (const [label, text] of Object.entries(variants)) {
  const { vectors } = await llm.embed(skills.map(text));
  const index = new MemorySkillIndex(
    skills,
    new Map(skills.map((s, i) => [s.id, vectors[i]])),
  );
  // threshold -1: always take the best match, then sweep cutoffs offline.
  const best = await normalizeSkills(
    pairs.map((p) => p.query),
    cachedEmbed,
    index,
    { threshold: -1 },
  );
  console.log(`\n=== skill text: "${label}"`);
  let top = { t: 0, acc: 0 };
  for (let t = 0.7; t <= 0.951; t += 0.01) {
    let tp = 0, fp = 0, wrong = 0, fn = 0, tn = 0;
    best.forEach((n, i) => {
      const predicted = (n.similarity ?? -1) >= t ? n.name : null;
      const expect = pairs[i].expect;
      if (expect === null) predicted === null ? tn++ : fp++;
      else if (predicted === expect) tp++;
      else predicted === null ? fn++ : wrong++;
    });
    const acc = (tp + tn) / pairs.length;
    if (acc > top.acc) top = { t, acc };
    console.log(
      `t=${t.toFixed(2)}  acc=${
        (acc * 100).toFixed(1)
      }%  mapped-right=${tp}  wrong-skill=${wrong}  missed=${fn}  false-map=${fp}  kept-unmapped=${tn}`,
    );
  }
  console.log(`best: t=${top.t.toFixed(2)} (${(top.acc * 100).toFixed(1)}%)`);
  console.log("per query (best match, similarity):");
  best.forEach((n, i) => {
    const ok = pairs[i].expect === null
      ? "·"
      : n.name === pairs[i].expect
      ? "✓"
      : "✗";
    console.log(
      `  ${ok} ${pairs[i].query.padEnd(42)} → ${
        String(n.name).padEnd(28)
      } ${n.similarity}  (want ${pairs[i].expect})`,
    );
  });
}
