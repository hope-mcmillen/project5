#!/usr/bin/env python3
"""Validate supabase/seed/skills.csv and skill_relations.csv (AI-01).

Checks: valid categories, unique names, lowercase aliases, no alias that
resolves to two different skills, and relations that reference real skills
with 0 < credit < 1. Exits non-zero on any problem.

Usage: python3 scripts/validate_taxonomy.py
"""
import csv
import sys
from pathlib import Path

SEED = Path(__file__).resolve().parent.parent / "supabase" / "seed"
CATEGORIES = {"Languages", "Frameworks", "Data", "Cloud/DevOps", "Tools", "Domain"}


def main() -> int:
    errors: list[str] = []
    names: dict[str, str] = {}  # lowercase key -> canonical name
    counts: dict[str, int] = {}

    with open(SEED / "skills.csv", newline="") as f:
        rows = list(csv.DictReader(f))
    for i, row in enumerate(rows, start=2):
        name, cat = row["name"].strip(), row["category"].strip()
        if cat not in CATEGORIES:
            errors.append(f"skills.csv:{i} {name}: bad category {cat!r}")
        key = name.lower()
        if key in names:
            errors.append(f"skills.csv:{i} duplicate name {name!r}")
        names[key] = name
        counts[cat] = counts.get(cat, 0) + 1

    # Aliases must not collide with another skill's name or alias.
    for i, row in enumerate(rows, start=2):
        name = row["name"].strip()
        for alias in filter(None, row["aliases"].split("|")):
            if alias != alias.lower() or alias != alias.strip():
                errors.append(f"skills.csv:{i} {name}: alias {alias!r} not lowercase/trimmed")
            owner = names.get(alias)
            if owner and owner != name:
                errors.append(f"skills.csv:{i} {name}: alias {alias!r} collides with {owner!r}")
            names.setdefault(alias, name)

    canonical = {r["name"].strip() for r in rows}
    seen_pairs = set()
    with open(SEED / "skill_relations.csv", newline="") as f:
        rels = list(csv.DictReader(f))
    for i, row in enumerate(rels, start=2):
        a, b = row["skill"].strip(), row["related"].strip()
        for s in (a, b):
            if s not in canonical:
                errors.append(f"skill_relations.csv:{i} unknown skill {s!r}")
        if a == b:
            errors.append(f"skill_relations.csv:{i} self-relation {a!r}")
        if (a, b) in seen_pairs:
            errors.append(f"skill_relations.csv:{i} duplicate pair {a!r} -> {b!r}")
        seen_pairs.add((a, b))
        credit = float(row["credit"])
        if not 0 < credit < 1:
            errors.append(f"skill_relations.csv:{i} credit {credit} not in (0, 1)")

    for e in errors:
        print("ERROR", e)
    print(f"{len(rows)} skills ({', '.join(f'{k} {v}' for k, v in sorted(counts.items()))}); "
          f"{len(rels)} relations; {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
