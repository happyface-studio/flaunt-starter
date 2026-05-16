# Setup Guide

End-to-end walkthrough for bootstrapping a new app from `flaunt-starter`. Allow ~30 minutes for a first run.

## 0. Prerequisites

Install these once, globally:

```bash
# Version manager (used to install Tuist)
curl https://mise.run | sh

# Supabase CLI
brew install supabase/tap/supabase

# GitHub CLI (only if you'll create the repo from the terminal)
brew install gh

# Node 20+
brew install node@20
```

You'll also need:

- **Xcode 16+** (iOS 18 toolchain).
- An **Apple Developer account** with team access.
- A **Supabase account** (free tier is fine for dev).
- Accounts for any third-party SDKs you keep: **PostHog**, **RevenueCat**, **OneSignal**.

## 1. Create the repo

From the GitHub UI: click **Use this template** on [happyface-studio/flaunt-starter](https://github.com/happyface-studio/flaunt-starter) → **Create a new repository**.

Or from the CLI:

```bash
gh repo create my-org/my-app --template happyface-studio/flaunt-starter --private --clone
cd my-app
```

## 2. Provision Supabase projects

You need **two** Supabase projects: one for dev/staging, one for production.

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**. Repeat for prod.
2. From each project's **Settings → General**, copy the **Project ref** (the string in the project URL, e.g. `wnspvizirwuhyzxymfbd`).
3. From **Settings → API**, copy the **Project URL** and the **anon public key** — you'll need these for the iOS app.

## 3. Run the rename script

```bash
./scripts/rename-app.sh "MyApp" "com.example.myapp" "<dev-project-ref>" "<prod-project-ref>"
```

This rewrites every `{{TOKEN}}` in docs/configs and the three identity constants (`appName`, `appDisplayName`, `bundleID`) in `ios/Project.swift`.

Verify no template tokens remain (the two doc-reference matches in `CLAUDE.md` / `README.md` are intentional):

```bash
grep -rn '{{[A-Z_]' --include='*.md' --include='*.toml' --include='*.json' --include='*.swift' --include='*.xcconfig' .
```

Commit the rename as a single commit so the template lineage stays readable:

```bash
git add -A && git commit -m "chore: rename template to MyApp"
```

## 4. Wire up the iOS app for local builds

```bash
cd ios
cp Secrets.xcconfig.template Secrets.xcconfig
```

Open `Secrets.xcconfig` and fill in your **dev** values:

```
SUPABASE_URL   = https://<dev-ref>.supabase.co
SUPABASE_KEY   = <dev anon key>

POSTHOG_API_KEY = phc_…
POSTHOG_HOST    = https://eu.i.posthog.com

REVENUECAT_API_KEY = appl_…

ONESIGNAL_APP_ID = <onesignal app id>
```

Leave any integration empty if you're not using it yet — the Kits handle missing values gracefully.

Generate the Xcode project and open it:

```bash
mise install                  # installs the pinned Tuist
tuist generate
open MyApp.xcworkspace
```

In Xcode:

1. Select the **App** target → **Signing & Capabilities**.
2. Pick your team.
3. **Sign in with Apple** capability is already declared — confirm it's enabled.
4. Build & run on a simulator. The auth screen should appear.

## 5. Push the starter migration

Still from the repo root:

```bash
cd backend
npm install
cp .env.template .env          # fill in dev SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY
npm run db:link:dev
npm run db:push
```

Verify in the Supabase dashboard → **Table Editor** → `public.posts` exists with RLS enabled.

Repeat for prod when you're ready:

```bash
npm run db:link:prod
npm run db:push
```

## 6. Configure Sign in with Apple in Supabase

In each Supabase project (dev + prod):

1. **Authentication → Providers → Apple** → enable.
2. **Client IDs**: enter your bundle ID (e.g. `com.example.myapp`).
3. **Secret Key (for OAuth)**: generate an Apple-signed JWT (see [Supabase docs](https://supabase.com/docs/guides/auth/social-login/auth-apple#configure-apple-as-third-party-oauth-provider)). Paste it into the **Secret** field.

The starter's `backend/supabase/config.toml` already wires the `[auth.external.apple]` block to read the secret from the `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET` env var, so you can also push this config via `supabase secrets set` if you prefer.

## 7. Set up Xcode Cloud CI/CD

In App Store Connect:

1. **Xcode Cloud → Manage Workflows → New Workflow** → connect this repo.
2. Pick the **App** scheme.
3. Add a **Start Condition** (e.g. push to `main` for prod, push to `dev` for staging).
4. Add an **Archive** action targeting App Store Connect (for distribution workflows).
5. **Environment → Variables** — add these as secret env vars on the workflow:

| Variable | Source | Required? |
|---|---|---|
| `SUPABASE_URL` | Supabase → Settings → API → Project URL | yes |
| `SUPABASE_KEY` | Supabase → Settings → API → anon public key | yes |
| `POSTHOG_API_KEY` | PostHog → Project settings | only if using PostHog |
| `POSTHOG_HOST` | PostHog → Project settings (e.g. `https://eu.i.posthog.com`) | only if using PostHog |
| `REVENUECAT_API_KEY` | RevenueCat → Project settings → API keys → Apple | only if using RevenueCat |
| `ONESIGNAL_APP_ID` | OneSignal → App settings → Keys & IDs | only if using OneSignal |

Use **separate workflows** for dev and prod so each can target the right Supabase project's keys.

Trigger a manual build to confirm:

- Logs show `Installing Tuist via mise...`
- Logs show `Injecting Supabase-Info.plist...` (and any other plists for env vars you set)
- Logs show `Running tuist generate...`
- The archive succeeds

## 8. Strip what you don't need

The starter ships full implementations for all five Kits. Common pruning:

- **No subscriptions?** Delete `Targets/InAppPurchaseKit/`, remove the `InAppPurchaseKit` entry from `Project.swift`, drop `requirePremium()` usages, remove the `REVENUECAT_API_KEY` env var from Xcode Cloud.
- **No push?** Same pattern for `Targets/NotifKit/`.
- **No analytics?** Same for `Targets/AnalyticsKit/`.

`SupabaseKit` and `SharedKit` are load-bearing — keep them.

Re-run `tuist generate` after touching `Project.swift`.

## 9. Day-to-day workflow

| Task | Command |
|---|---|
| Run local Supabase stack | `cd backend && npm run db:local:dev` |
| Create a new migration | `cd backend && npm run db:migration:new <name>` |
| Push migrations to dev | `cd backend && npm run db:link:dev && npm run db:push` |
| Push migrations to prod | `cd backend && npm run db:link:prod && npm run db:push` |
| Regenerate Xcode project | `cd ios && tuist generate` |
| Add an edge function | `cd backend && supabase functions new <name>` |
| Deploy edge functions | `cd backend && npm run functions:deploy` |

See [`CLAUDE.md`](./CLAUDE.md), [`ios/CLAUDE.md`](./ios/CLAUDE.md), and [`backend/CLAUDE.md`](./backend/CLAUDE.md) for deeper conventions.

## Troubleshooting

**`tuist generate` fails with "Tuist not found"** — run `mise install` from the `ios/` directory; the Tuist version is pinned in `ios/.mise.toml`.

**Xcode Cloud build fails at the Tuist install step** — confirm `ios/ci_scripts/ci_post_clone.sh` is executable (`chmod +x` it before committing) and `ios/.mise.toml` is committed.

**Auth works locally but not in TestFlight build** — the `SUPABASE_URL` / `SUPABASE_KEY` env vars aren't set on the Xcode Cloud workflow. Check the workflow logs for `Injecting Supabase-Info.plist...`; if missing, the env vars weren't set.

**`db:push` writes to the wrong project** — the CLI is linked to whichever project ref you ran `db:link:*` with last. Always run `npm run db:link:dev` or `:prod` before `db:push`.

**RLS blocks queries in the iOS app** — `posts` rows must have `user_id = auth.uid()`. Make sure the user is signed in (`SupabaseBackend.shared.currentUser != nil`) before reading or writing.
