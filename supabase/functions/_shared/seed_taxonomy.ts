// Dev/test helper: load the taxonomy from supabase/seed/ (skills.csv and the
// generated skills_embeddings.sql) into a MemorySkillIndex, so scripts and
// tests can normalize skills without a database. Not used by Edge Functions.
import { MemorySkillIndex, type TaxonomySkill } from "./normalize.ts";

const SEED = new URL("../../seed/", import.meta.url);

export interface SeedSkill extends Omit<TaxonomySkill, "id"> {}
export interface SeedRelation {
  skill: string;
  related: string;
  credit: number;
}

/** skills.csv has no quoted fields (validate_taxonomy.py guarantees no commas in values). */
function readCsv(text: string): Record<string, string>[] {
  const [header, ...rows] = text.trim().split(/\r?\n/);
  const cols = header.split(",");
  return rows.map((r) => Object.fromEntries(r.split(",").map((v, i) => [cols[i], v.trim()])));
}

export async function loadSeedSkills(seed = SEED): Promise<SeedSkill[]> {
  return readCsv(await Deno.readTextFile(new URL("skills.csv", seed))).map((r) => ({
    name: r.name,
    category: r.category,
    aliases: (r.aliases ?? "").split("|").filter(Boolean),
  }));
}

export async function loadSeedRelations(seed = SEED): Promise<SeedRelation[]> {
  return readCsv(await Deno.readTextFile(new URL("skill_relations.csv", seed))).map((r) => ({
    skill: r.skill,
    related: r.related,
    credit: Number(r.credit),
  }));
}

/** Vectors from skills_embeddings.sql, keyed by skill name, plus the model tag they were made with. */
export async function loadSeedEmbeddings(
  seed = SEED,
): Promise<{ model: string | null; vectors: Map<string, number[]> }> {
  let sql: string;
  try {
    sql = await Deno.readTextFile(new URL("skills_embeddings.sql", seed));
  } catch (e) {
    if (e instanceof Deno.errors.NotFound) return { model: null, vectors: new Map() };
    throw e;
  }
  const vectors = new Map<string, number[]>();
  let model: string | null = null;
  const re = /set embedding = '\[([^\]]*)\]'[^,]*, embedding_model = '([^']*)' where name = '((?:[^']|'')*)';/g;
  for (const m of sql.matchAll(re)) {
    vectors.set(m[3].replaceAll("''", "'"), m[1].split(",").map(Number));
    model = m[2];
  }
  return { model, vectors };
}

/** Taxonomy index with ids = skill names (the seed has no UUIDs). */
export async function seedSkillIndex(seed = SEED): Promise<MemorySkillIndex> {
  const skills = await loadSeedSkills(seed);
  const { vectors } = await loadSeedEmbeddings(seed);
  return new MemorySkillIndex(skills.map((s) => ({ id: s.name, ...s })), vectors);
}
