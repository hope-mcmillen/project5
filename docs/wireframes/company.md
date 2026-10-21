# Company wireframes (RC-07, RC-18, D4)

## Company setup `/r/onboarding`

```
┌──────────────────────────────┐
│ Set up your company          │
│ You'll post jobs and review  │
│ applicants from one shared   │
│ workspace.                   │
│ ┌──────────────────────────┐ │
│ │ ◆+ Create a company      │ │
│ │ You'll be the owner.     │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ ⧉ Join with a code       │ │
│ │ A teammate sent you one. │ │
│ └──────────────────────────┘ │
│        Sign out              │
└──────────────────────────────┘
```
Wide: the two option cards side by side.

## Create company `/r/onboarding/create`

```
│ ← Create company             │
│  ┌────┐                      │
│  │logo│  Add logo (optional) │  PNG/JPEG/WebP ≤ 5 MB
│  └────┘                      │
│ Name     [______________]    │  required, ≤ 120
│ Website  [https://______]    │  optional, http(s) URL
│ [       Create company     ] │
```
Errors: field-level validation, `invalid_company` and `already_in_company`
in a banner above the button.

## Join company `/r/onboarding/join`

```
│ ← Join company               │
│ Enter the 8-character code   │
│ from your teammate.          │
│ Code [A B C D 2 3 4 5]       │  auto-uppercase, max 8
│ [          Join            ] │
```
`invalid_invite` → "That code is invalid, expired, or used up."

## Company settings `/r/company` (shell tab)

```
Compact                          Wide (two columns)
┌──────────────────────────────┐ ┌───────────────┬───────────────────────┐
│ Company                      │ │ [logo] Name   │ Invite codes          │
│ [logo] Rhombus Labs          │ │ ✓ Verified    │ [ Generate code ]     │
│ rhombus.example.test         │ │ website       │ ABCD2345 · 7 days · ⧉ ✕│
│ ◇ Unverified (i)             │ │ You: Owner    │ FAKE0000 · revoked    │
│ You're the owner             │ │               │                       │
│ Invite codes                 │ │ [ Sign out ]  │                       │
│ [ Generate code ]            │ └───────────────┴───────────────────────┘
│ ABCD2345  expires Oct 28 ⧉ ✕ │
│ [ Sign out ]                 │
└──────────────────────────────┘
```
Members see the company card and Sign out, without the invite section.
Empty invites: "No active codes. Generate one to invite a teammate."
Revoke asks for confirmation.
