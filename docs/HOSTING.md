# Hosting the recruiter portal (RC-21)

The recruiter side runs as a Flutter web app. It's a static site: build it
once, upload `build/web`, and point Supabase Auth at its URL.

## 1. Config

Create `env/prod.json` next to `env/dev.json` (same keys). Use the hosted
project's URL and its **publishable / anon** key from the Supabase dashboard
(Project Settings → API Keys). Never put the secret or service-role key in
any app config: everything in a web build is public.

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_…"
}
```

## 2. Build

```sh
flutter build web --release --dart-define-from-file=env/prod.json
```

The app uses path URLs (`/r/jobs/<id>/board`, no `#`), so the host must
serve `index.html` for every path:

- **Netlify:** `web/_redirects` is copied into `build/web` and already does
  this. Drag `build/web` onto https://app.netlify.com/drop, or run
  `netlify deploy --prod --dir build/web`.
- **Vercel:** deploy `build/web` with a rewrite of `/(.*)` to `/index.html`.
- **GitHub Pages:** copy `build/web/index.html` to `build/web/404.html`, and
  build with `--base-href /<repo>/` when serving from a project subpath.

## 3. Supabase Auth URLs

In the dashboard, Authentication → URL Configuration:

- **Site URL:** the hosted URL, e.g. `https://resurhombus.netlify.app`.
- **Redirect URLs:** add `https://resurhombus.netlify.app/**` (email
  confirmation, password reset and Google sign-in return here) and keep
  `io.resurhombus.app://login-callback` for Android.

## 4. Check it

Open the hosted URL in a private window and confirm:

1. Sign in as a recruiter, refresh on a board URL: the same board reloads.
2. "Forgot password" sends an email whose link opens the reset page.
3. The layout works at phone width and on a laptop. The employer menu opens a left sidebar with Interviews, Company Profiles, and Job Postings, preserving each section's navigation state.
