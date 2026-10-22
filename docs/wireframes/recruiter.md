# Recruiter wireframes (RC-05 to RC-16)

## Shell (RC-05)

```
Compact (< 900)                Wide (≥ 900; extended labels ≥ 1200)
┌──────────────────────────┐   ┌────┬──────────────────────────────┐
│ page                     │   │ ◆  │ page                         │
│                          │   │Jobs│                              │
│                          │   │Intv│                              │
├──────────────────────────┤   │Co. │                              │
│ Jobs  Interviews Company │   └────┴──────────────────────────────┘
└──────────────────────────┘
```

## Jobs list `/r/jobs` (RC-06)

```
Compact: ListView                    Wide: DataTable
┌────────────────────────────┐       Title          Status  New Total  ⋯
│ Jobs              [+ New]  │       Flutter Dev    OPEN     3    5    ⋯
│ Flutter Developer  [OPEN]  │       Backend Eng.   DRAFT    –    –    ⋯
│ 3 new · 5 total         ⋯  │
│ Backend Engineer  [DRAFT]  │       ⋯ menu: Publish / Pause / Close
└────────────────────────────┘
```
Empty: "Post your first job" + **New job**. Pull to refresh.

## New job `/r/jobs/new` (RC-08)

Large multiline field ("Paste the job description"), a `12,345 / 20,000`
counter, **Read description**. While parsing: progress, "You can leave this
page"; then go to Requirements. Error: retry + keep the text.

## Requirements `/r/jobs/:id/requirements` (RC-09)

```
Wide: JD panel | requirement table
┌──────────────────────┬───────────────────────────────────────────┐
│ Job description text │ 8/8 required · 12/15 total    [+ Add skill]│
│ …evidence highlighted│ Skill    Required/Preferred  Years  Weight│
│                      │ Flutter  [Req|Pref]          [-2+]  ◆◆◇  │
│                      │ Unmapped: "Riverpod" → map to…           │
└──────────────────────┴───────────────────────────────────────────┘
```
Compact: one card per requirement; the JD opens in a bottom sheet.

## Job details `/r/jobs/:id/details` (RC-10)

Location, remote chips (onsite/hybrid/remote), job type, sponsorship switch,
salary min/max (min ≤ max), **Save** and **Publish**.

## Board `/r/jobs/:id/board` (RC-12, RC-13)

```
Flutter Developer · 5 applicants · Sorted by Match
┌────────┐┌────────┐┌────────┐┌────────┐   1–5 columns, max 320 px each
│◆ 4F2A ▲││◆ 9C1B  ││◆ 2D7E  ││        │   ▲ advance / ▼ reject on hover
│87 Strong││74 Good ││58 Stret││        │   (tap toggles on touch)
│4.5 yrs ▼││2 yrs   ││1 yr    ││        │
│Flutter… ││Dart…   ││JS…     ││        │
└────────┘└────────┘└────────┘└────────┘
```
No names or photos. Empty: "No applicants yet". Reject shows
"Not a fit · Undo" for 10 s.

## Candidate detail `/r/jobs/:id/board/:appId` (RC-15)

Radar deep dive, per-skill evidence, ▲ Advance / ▼ Not a fit. Wide: a side
panel next to the grid. Identity appears only after advancing.

## Interviews `/r/interviews` (RC-16)

Rows: name · job · score · **Email** · **Resume**, with a job filter.
Empty: "Advance a candidate to see them here."
