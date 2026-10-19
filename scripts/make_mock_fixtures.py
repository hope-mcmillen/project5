#!/usr/bin/env python3
"""Generate MockProvider job fixtures from the fake JDs and their labels (AI-03).

For each supabase/seed/jobs/*.txt, writes
  supabase/functions/_shared/fixtures/extract/<sha256(normalized text)>.json
with a schema-valid `job` extraction whose evidence quotes are real lines of
the JD. job01 is also written as default.job.json. Re-run after editing a JD
or labels.json. Standard library only.

Usage: python3 scripts/make_mock_fixtures.py
"""
import csv
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED = ROOT / "supabase" / "seed"
OUT = ROOT / "supabase" / "functions" / "_shared" / "fixtures" / "extract"

# Same characters as JavaScript's \s, so keys match llm.ts normalizeForKey().
JS_WS = re.compile("[\t\n\v\f\r    -     　﻿]+")

# Job fields a correct extraction returns (hand-labeled from each JD header).
META = {
    "job01_flutter_mobile.txt": ("Mobile Engineer (Flutter)", "Baton Rouge, LA", "hybrid", False, 95000, 120000),
    "job02_python_backend.txt": ("Backend Engineer, Python", None, "remote", True, 120000, 150000),
    "job03_data_engineer.txt": ("Data Engineer", "New Orleans, LA", "onsite", False, 110000, 135000),
    "job04_devops_sre.txt": ("DevOps / Site Reliability Engineer", None, "remote", True, 130000, 160000),
    "job05_frontend_react.txt": ("Frontend Engineer (React)", "Austin, TX", "hybrid", False, 105000, 130000),
    "job06_ml_engineer.txt": ("Machine Learning Engineer", "Houston, TX", "hybrid", True, 140000, 175000),
}
REQUIRED_HEADINGS = re.compile(r"^(required|requirements|must have)\b", re.I)
PREFERRED_HEADINGS = re.compile(r"^(preferred|nice to have|bonus)\b", re.I)


def fixture_key(text: str) -> str:
    return hashlib.sha256(JS_WS.sub(" ", text).strip().encode()).hexdigest()


def sections(text: str):
    """Map each line to 'required', 'preferred', or None by its heading."""
    current, out = None, []
    for line in text.splitlines():
        s = line.strip()
        if s and not s.startswith("-"):
            current = ("required" if REQUIRED_HEADINGS.match(s)
                       else "preferred" if PREFERRED_HEADINGS.match(s) else None)
        out.append((current, s))
    return out


def find(terms, lines, want):
    """First line (preferring section `want`) containing a term; returns (line, surface text)."""
    ordered = [l for sec, l in lines if sec == want] + [l for sec, l in lines if sec != want]
    for line in ordered:
        for t in terms:
            m = re.search(r"(?<![\w])" + re.escape(t) + r"(?![\w])", line, re.I)
            if m:
                return line.lstrip("- ").strip(), m.group(0)
    return None


def main():
    with open(SEED / "skills.csv", newline="") as f:
        terms = {r["name"]: [r["name"].lower()] + [a for a in r["aliases"].split("|") if a]
                 for r in csv.DictReader(f)}
    labels = json.loads((SEED / "fixtures" / "labels.json").read_text())["jobs"]
    OUT.mkdir(parents=True, exist_ok=True)

    for name, (title, location, remote, sponsorship, smin, smax) in META.items():
        text = (SEED / "jobs" / name).read_text()
        lines = sections(text)
        wanted = [(r["skill"], "required", r["min_years"] or None) for r in labels[name]["required"]]
        wanted += [(s, "preferred", None) for s in labels[name]["preferred"]]
        reqs = []
        for skill, hint, years in wanted:
            hit = find(terms[skill], lines, hint)
            if not hit:
                raise SystemExit(f"{name}: no evidence line for {skill}")
            evidence, surface = hit
            reqs.append({"raw": surface, "required_hint": hint, "min_years": years, "evidence": evidence})
        extraction = {"title": title, "location": location, "remote": remote, "job_type": "full_time",
                      "sponsorship": sponsorship, "salary_min": smin, "salary_max": smax, "requirements": reqs}
        body = json.dumps(extraction, indent=2) + "\n"
        path = OUT / f"{fixture_key(text)}.json"
        path.write_text(body)
        print(f"wrote {path.relative_to(ROOT)}  ({name}, {len(reqs)} requirements)")
        if name.startswith("job01"):
            (OUT / "default.job.json").write_text(body)


if __name__ == "__main__":
    main()
