# Parker Water Products — Sales & Order Tracking

Android app for order takers to log sales orders in under a minute (works offline), plus a web admin panel (same Flutter codebase, hosted on Vercel) for orders, filters, summaries, Excel export, users and master data. Backend is Supabase (Postgres + Auth + Edge Functions).

```
app/                     Flutter app (Android APK + web admin panel)
  lib/data/              API client, models, on-device store, Excel import parser
  lib/state/             session, master-data cache, offline sync queue
  lib/ui/                order taker screens; ui/admin/ admin screens
  lib/l10n/app_en.arb    every UI string (add app_hi.arb / app_gu.arb for Hindi / Gujarati)
supabase/
  migrations/            schema, RLS, order/search/summary/import SQL functions
  functions/             admin-users (logins), export-orders (.xlsx)
  seed.sql               sample products, vehicles, parties, rates
scripts/                 create-user.mjs (bootstrap admin), backend.test.mjs, Vercel build
.github/workflows/       CI, signed APK on tag, daily encrypted DB backup
vercel.json              web admin hosting
```

## How it works

- **Login**: user ID + password. Behind the scenes Supabase Auth uses `<userid>@parker.local` (passwords bcrypt-hashed by Supabase Auth). No self-signup; admins create users.
- **Roles** are rows in `roles` (`admin`, `order_taker`) — add a Supervisor/Driver role with an `INSERT`, no schema change.
- **Security**: row-level security on every table. Order takers can read only their own orders; master data is read-only for them. All order writes go through validated SQL functions (`submit_order`, `update_order`, `set_order_status`), so rules hold even if the app is tampered with. Admin-only edge functions verify the caller's token and role server-side. Only the public anon key ships in the APK.
- **Rates are never typed**: the server copies the rate from the party's rate list (latest `effective_from` ≤ order date, else product default rate) into `order_items.rate` at save time. Later rate changes never alter past orders.
- **Order numbers**: `PWP-2026-000123`, per-year counter, gap-free, assigned by the database.
- **Offline**: products/parties/vehicles/rates are cached on the phone; a new order is written to a local queue first, then synced (on reconnect, app resume, every minute). The phone generates the order id, so a retried sync never creates a duplicate. Queued orders show a **Pending sync** badge.
- **Audit**: `created_at/by` are immutable (trigger-enforced), `updated_at/by` on every edit, every master-data and order change is copied to `audit_log`, every status change to `order_status_log`. Users and masters are soft-deleted (`is_active`).
- **Time**: stored UTC; day boundaries, order-number year, reports and display use the plant time zone (`plant_tz()` in SQL = `Asia/Kolkata`, `AppConfig.plantUtcOffset` in Dart).

## PRD coverage

| ID | Requirement | Status |
| --- | --- | --- |
| FR-01 | Login with user ID + password, session persists | Done |
| FR-02 | Role check on every API call | Done (RLS + SQL functions + edge functions) |
| FR-03 | Admin CRUD users, products, vehicles, parties | Done (soft delete only) |
| FR-04 | Per-party rate list with effective-from | Done, with rate history |
| FR-05 | New Order form, rate auto-fill | Done (+ "Repeat last order" chip: repeat order = 3 taps) |
| FR-06 | "No vehicle" always offered | Done (first option) |
| FR-07 | Created/updated timestamp + user on every record | Done |
| FR-08 | Sequential human-readable order no | Done |
| FR-09 | Order taker sees/edits only own orders | Done (edit until status leaves Submitted) |
| FR-10 | All Orders view, combinable filters | Done (date range, party, product, vehicle, taker, status, text search) |
| FR-11 | Excel export, Orders + Order Lines sheets | Done (exactly the filtered rows; download on web, share sheet on Android) |
| FR-12 | Offline capture with queued sync | Done |
| FR-13 | Summary by party / product / vehicle / user / day | Done |
| FR-14 | Bulk import parties + rates from Excel | Done (template download in the app) |
| FR-15 | Status lifecycle Submitted → Delivered / Cancelled | Done (admin; logged) |
| FR-16 | Change own password | Done |
| FR-17 | Audit log | Data captured in `audit_log` (admin read-only); no viewer screen yet |
| FR-18 | Rate override by order taker | Not built — waiting on open question |
| FR-19 | Daily summary push (WhatsApp/email) | Not built (Could) |

## Go-live runbook

You need: a Supabase account, a Vercel account, Node 18+, the [Supabase CLI](https://supabase.com/docs/guides/cli), Flutter 3.47 (or use the GitHub Actions workflows).

### 1. Backend (Supabase)

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase db push                       # applies supabase/migrations
supabase functions deploy admin-users --no-verify-jwt
supabase functions deploy export-orders --no-verify-jwt
```

`--no-verify-jwt` is intentional: both functions verify the caller's token themselves (`auth.getUser` + `is_admin`), which also works with Supabase's newer signing keys.

In the Supabase dashboard → Authentication → Providers → Email: **disable "Allow new users to sign up"** and **disable "Confirm email"**. Sample data (optional, for a trial run): paste `supabase/seed.sql` into the SQL editor.

Create the first admin (the service-role key stays on your machine — never put it in the app or the repo):

```bash
cd scripts && npm install
SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
  node create-user.mjs admin "Plant Admin" admin '<strong-password>'
```

Every other user is created from the app (Admin → Users).

### 2. Web admin panel (Vercel)

Import the GitHub repo in Vercel (framework: Other; `vercel.json` already sets install/build/output). Add environment variables `SUPABASE_URL` and `SUPABASE_ANON_KEY` (Supabase → Project Settings → API). Every push to `main` redeploys. Add the client's domain under Vercel → Domains.

### 3. Android APK

Generate the client's signing key once and keep it safe (losing it means users must uninstall to update):

```bash
keytool -genkey -v -keystore parker-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Local build — create `app/android/key.properties` (git-ignored):

```
storeFile=/absolute/path/parker-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

then

```bash
cd app
cp config.example.json config.json     # fill in SUPABASE_URL and SUPABASE_ANON_KEY
flutter build apk --release --dart-define-from-file=config.json
# → app/build/app/outputs/flutter-apk/app-release.apk
```

Or via CI: add repository secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ANDROID_KEYSTORE_BASE64` (`base64 -w0 parker-upload.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, then push a tag `v1.0.0`; the signed APK is attached to the GitHub Release.

### 4. Backups

Supabase's free tier has no automatic backups. `.github/workflows/backup.yml` runs a daily `pg_dump` (public + auth schemas), encrypts it with GPG and keeps it 30 days as a private workflow artifact. Secrets: `SUPABASE_DB_URL` (Project Settings → Database → session pooler connection string) and `BACKUP_PASSPHRASE`. Restore: `gpg -d file.dump.gpg > file.dump && pg_restore --clean -d "$DB_URL" file.dump`. (On Supabase Pro you also get managed daily backups.)

## Local development

```bash
supabase start                 # Postgres, Auth, REST, Edge runtime in Docker
supabase db reset              # migrations + seed
supabase functions serve &     # edge functions
cd scripts && npm install
eval "$(supabase status -o env | sed 's/^/export /')"
export SUPABASE_URL=$API_URL SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY SUPABASE_ANON_KEY=$ANON_KEY
node create-user.mjs admin "Plant Admin" admin admin1234
node create-user.mjs ravi "Ravi Kumar" order_taker ravi1234
node create-user.mjs sunil "Sunil Joshi" order_taker sunil1234
node --test backend.test.mjs   # 14 integration tests: RLS, rates, idempotent sync, filters, import, users, export

cd ../app
flutter test
flutter run -d chrome --dart-define=SUPABASE_URL=$API_URL --dart-define=SUPABASE_ANON_KEY=$ANON_KEY
```

(Android emulator: use `http://10.0.2.2:54321` as the URL.)

## Decisions and assumptions

- **On-device storage** uses `shared_preferences` (JSON) instead of Drift/SQLite: the data is small (masters + a handful of queued orders), it works identically on Android and web, and it avoids code generation. Swap in Drift if the party list grows into the tens of thousands.
- **Plant time zone** is assumed to be IST (Asia/Kolkata). Change `plant_tz()` (new migration) and `AppConfig.plantUtcOffset` if not.
- **Order number** format `PWP-YYYY-NNNNNN`, counter restarts each year.
- **Edits**: an order taker can edit their own order while it is Submitted (online only). Lines already on the order keep their saved rate; new lines (or a party change) take the current rate. Only admin changes status; cancel keeps the record.
- **Inactive masters** stay readable so old orders display correctly; the order form offers only active ones. An order queued offline still syncs if its party/product was deactivated meanwhile.
- **Android**: portrait only; `minSdk` is Flutter's default (Android 7+), which covers the Android 10+ target.
- **Totals** in summaries include all statuses matching the filter — filter Status to exclude Cancelled.

## Open questions (from the PRD) still to confirm with Parker Water

Quantity slabs / date-based rates, rate override by order takers, statuses beyond Delivered/Cancelled (Paid?), driver role, Excel template requirements, APK vs Play internal track, admin domain, real data volumes, Hindi/Gujarati in v1.
