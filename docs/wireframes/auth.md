# Auth wireframes (PL-10, D2)

Auth pages are single-column at every width: max 440 px wide, centered.

## Welcome `/welcome` (`?role=recruiter` preselects "I'm hiring")

```
┌──────────────────────────────┐
│          ◆ ResuRhombus       │
│  Swipe into the right job.   │
│                              │
│ ┌──────────────────────────┐ │
│ │ [card stack art]         │ │
│ │ I'm looking for a job    │ │  RoleChoiceCard (selected: 2px
│ └──────────────────────────┘ │  border + check rhombus)
│ ┌──────────────────────────┐ │
│ │ [tile mosaic art]        │ │
│ │ I'm hiring               │ │
│ └──────────────────────────┘ │
│ [        Continue        ]   │  disabled until a card is picked
│  Already have an account?    │
│  Sign in                     │
└──────────────────────────────┘
```
Wide: the two cards sit side by side (each ~260 px).

## Role choice `/welcome/role` (signed in, no role yet)

Same two RoleChoiceCards, heading "How will you use ResuRhombus?",
**Continue** calls `set_initial_role`. Error banner above the button. Plus a
"Sign out" text button.

## Sign up `/sign-up?role=…`

```
┌──────────────────────────────┐
│ ← Create your account        │
│  Signing up as: Candidate ▾  │  chip; tap to switch role
│ Email     [______________]   │
│ Password  [______________] 👁 │  ≥ 8 characters
│ [✓] I agree to the Terms     │
│ [      Create account     ]  │
│ ──────────── or ───────────  │
│ [ G  Continue with Google ]  │
│  Have an account? Sign in    │
└──────────────────────────────┘
```

## Sign in `/sign-in`

Email, password, **Sign in**, "Forgot password?", the Google button, and
"New here? Get started". Wrong credentials: inline error above the button.

## Forgot password `/forgot-password`

Email + **Send reset link**. After sending, the form is replaced by
"Check your email" and a **Back to sign in** button (same message whether or
not the account exists).

## Reset password `/reset-password` (opened from the email link)

New password + confirm, **Save password**. Success signs the user in and
routes them home.
