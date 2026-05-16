# flaunt-starter

iOS + Supabase + Xcode Cloud app starter template, derived from [happyface-studio/Flaunt](https://github.com/happyface-studio/Flaunt).

Ships with:

- **SwiftUI app** (Tuist multi-target) — `ios/`
  - App + 5 Kits: SharedKit, SupabaseKit, AnalyticsKit, InAppPurchaseKit, NotifKit
  - Sign in with Apple + email auth, sample `posts` CRUD, paywall, push notifs, analytics
- **Supabase backend** — `backend/supabase/`
  - `supabase init` config, starter `posts` migration with RLS, npm scripts for the CLI
- **Xcode Cloud CI/CD** — `ios/ci_scripts/ci_post_clone.sh`
  - Installs Tuist via `mise`, injects secrets from workflow env vars into per-Kit plists, runs `tuist generate`
- **CLAUDE.md** set for agent-driven development — root, `ios/`, `backend/`
- **Token-based bootstrapping** — `scripts/rename-app.sh` rewrites every `{{TOKEN}}` and the iOS identity constants in one command

## Bootstrap a new app

```bash
# 1. Use this template (GitHub UI) or clone manually:
gh repo create my-org/my-app --template happyface-studio/flaunt-starter --private --clone
cd my-app

# 2. Run the rename script
./scripts/rename-app.sh "MyApp" "com.example.myapp" "<dev-project-ref>" "<prod-project-ref>"

# 3. Local iOS dev
cd ios
cp Secrets.xcconfig.template Secrets.xcconfig   # fill in your dev keys
mise install
tuist generate
open MyApp.xcworkspace

# 4. Local backend dev (optional)
cd ../backend
npm install
npm run db:link:dev
npm run db:push
```

## Set up Xcode Cloud

In App Store Connect → Xcode Cloud → Workflow → Environment, add:

| Variable | Source |
|---|---|
| `SUPABASE_URL`, `SUPABASE_KEY` | Supabase project settings |
| `POSTHOG_API_KEY`, `POSTHOG_HOST` | PostHog project settings |
| `REVENUECAT_API_KEY` | RevenueCat app config |
| `ONESIGNAL_APP_ID` | OneSignal app settings |

Each is optional — `ci_post_clone.sh` skips injecting any plist whose env vars are unset.

## Docs

- [`SETUP.md`](./SETUP.md) — Full setup walkthrough (Supabase, Xcode Cloud, Apple sign-in)
- [`CLAUDE.md`](./CLAUDE.md) — Project conventions, architecture, environments
- [`ios/CLAUDE.md`](./ios/CLAUDE.md) — Tuist modules, secrets, code style
- [`backend/CLAUDE.md`](./backend/CLAUDE.md) — Migrations, edge functions, npm scripts
