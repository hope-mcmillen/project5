---
name: resurhombus-prd
description: Keeper of the ResuRhombus product requirements in docs/PRD.md. Use this skill whenever the user makes or discusses a product or architecture decision, answers an open question, changes a flow, status, screen, score rule, or tech choice, asks "what does the PRD say about X", or asks to refine requirements, add a flow diagram, or update the doc, so that decisions land in the PRD consistently instead of drifting.
---

# ResuRhombus PRD Keeper

`docs/PRD.md` is the single source of truth for what ResuRhombus does and how it's built. The other project skills (ui, flutter, supabase, matching) point into it by section number, so it has to stay accurate and stable.

## When answering questions
Quote the relevant section number and requirement ID (e.g., "§5.2, C-SW-2"). If the PRD is silent or contradicts the code, say so plainly and offer to resolve it. Don't invent an answer and present it as the spec.

## When a decision is made
1. **Find every place it touches.** Search the doc for related terms. Decisions usually ripple into a flow diagram, a requirements list, the architecture tables (§9), phasing (§10), and open questions (§12).
2. **Edit in place.** Keep requirement IDs stable (`C-ON-*`, `C-SW-*`, `R-JOB-*`, `R-TRI-*`, `A-*`, `X-*`). Add new IDs at the end of a list instead of renumbering. Code comments and tests may reference them.
3. **Bump the version** in the header (0.x → 0.x+1) and update the date. Add a `### v0.x decisions` block at the top of §0 Changelog with one bullet per decision, explaining what changed and why.
4. **Close open questions** by striking them through in §12 (`~~Q8~~`) and adding "**Decided (v0.x):** …". Add new questions the decision raises, each with a recommendation.
5. **Keep section numbers stable.** If inserting a section is unavoidable, renumber the headings and every `§` cross-reference in the same edit, then grep for `§` to verify. Also check the other skills in `.claude/skills/`, which cite section numbers.
6. **Mermaid diagrams must render on GitHub.** Avoid `[]` or `()` in ER attribute types, and quote labels that contain special characters.

## Style
- Use tables for comparisons and specs, Mermaid for flows and state machines, and short bullets for requirements.
- Give a recommendation with each open question, not just the question.
- Facts that change over time, like prices, limits, and laws, should be written as "verify before launch" notes, not stated as settled.
- Don't commit unless the user asks. When they do, use a message like `docs(prd): v0.5 – <decisions>`.
