# Printremeras — custom apparel printing platform

Customers upload artwork, position it on a garment mockup inside the printable area and order.
A catalog sells ready-made designs built by staff in the same editor. After delivery, customers
submit a photo review; once approved they receive a discount coupon.

| Layer | Choice |
|---|---|
| Backend | Ruby on Rails 8.1 (JSON API + server-rendered admin at `/admin`) |
| Database | PostgreSQL (primary + Solid Cache / Solid Queue / Solid Cable databases) |
| Storage | ActiveStorage → Cloudflare R2 / S3 (two buckets: public + private); local disk in dev |
| Images | libvips via `ruby-vips` / `image_processing` |
| Frontend | React 18 + Vite 5 + TypeScript + Tailwind (`frontend/`), built into `public/app` |
| Payments | MercadoPago (Checkout Pro, redirect + QR) behind a gateway interface; `FakeGateway` in dev |
| Locales | es (default), ru |

Low-resolution artwork is accepted rather than rejected: it is flagged in Admin → Calidad de
arte and can be sent to an upscaling provider (`IMAGE_ENHANCEMENT_PROVIDER`) before printing.

Architecture notes (ports & adapters, domain events, module map): [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
Decisions taken on the spec's open questions and gaps: [docs/DECISIONS.md](docs/DECISIONS.md).

---

## 1. Local development

### Requirements
- Ruby 3.2 (`.ruby-version`), Bundler
- Node 18+ (20 recommended) and npm
- PostgreSQL 14+ running locally (the app creates its databases; the DB role needs `CREATEDB`)
- libvips (`brew install vips` / `apt install libvips`)

### First run
```bash
bin/setup            # bundle + npm install, .env from .env.example, db:prepare, db:seed, then starts bin/dev
```
`bin/dev` runs three processes (Procfile.dev): Rails on **http://localhost:3000**, the Solid Queue
worker (`bin/jobs`) and the Vite dev server on **http://localhost:5173**.

- Storefront (dev): **http://localhost:5173** (Vite proxies `/api`, `/rails`, `/auth`, `/cable`… to Rails)
- Admin: **http://localhost:3000/admin** — `admin@printremeras.local` / `changeme-admin-1`
  (operator: `operator@printremeras.local` / `changeme-operator-1`). Change these with `ADMIN_EMAIL` / `ADMIN_PASSWORD` in `.env` before seeding.
- Demo customer: `cliente@printremeras.local` / `password123`.

Both login screens list the accounts that can actually sign in there (customers on the
storefront, staff at `/admin`) and fill the form when you tap one
(`lib/dev_credentials.rb` is the single place the passwords are written). They are on by
default in development and omitted everywhere else, so a deployed build shows nothing.
To demo them in the docker compose stack (which runs `RAILS_ENV=production`), set
`SHOW_DEV_CREDENTIALS=true` in `.env` — the screens then carry a visible warning and the
app logs one at boot. Remove it before pointing the stack at a public domain.
`HIDE_DEV_CREDENTIALS=true` turns the shortcuts off everywhere.
- Job dashboard: http://localhost:3000/admin/jobs (admins only)
- Language: the admin top bar has an Español/Русский switcher (stored on the admin user,
  and used for their emails); the storefront has one in its header. `?locale=ru` also works
  on any URL. A third language needs `config/locales/*.<code>.yml` plus
  `frontend/src/locales/<code>.json` and one line in the i18n registry, no other code.
- Emails open in the browser (letter_opener) unless `SMTP_ADDRESS` is set.
- Payments use `Payments::FakeGateway`: "Pay" sends you to `/dev/payments/:id` where you can
  simulate approval, rejection, a delayed webhook or a wrong amount.

Seeds create three demo garments (with generated mockups) so the editor works immediately.
Upload a real mockup photo per side in Admin → Prendas and drag the print rectangle over it.

### Useful commands
```bash
bin/rails test                     # backend test-suite (models, services, API, admin)
cd frontend && npm run build       # type-check + build the storefront into public/app
bin/rails db:seed                  # idempotent: admin user (+ demo data in development)
bin/jobs                           # Solid Queue worker on its own
bin/rails runner 'Setting.set(:rush_enabled, true)'
```
Without the Vite dev server Rails serves the built SPA from `public/app` (run `npm run build` first).

**Known macOS quirk.** On start-up, one Solid Queue child process can segfault in `libpq`
right after `fork`, print a crash dump, and be replaced by the supervisor. The queue works
normally afterwards (jobs are picked up and finished), and Linux containers are unaffected,
so this is noise rather than a failure. If the dumps bother you, run jobs inside the web
process with `SOLID_QUEUE_IN_PUMA=true bin/rails server` and drop the `jobs` line from
`Procfile.dev`.

---

## 2. Configuration and credentials

Everything is environment-driven; see **`.env.example`** for the full list with comments.
Business settings (shipping fee, pickup address, reward %, DPI, coupon validity, MercadoPago
keys…) live in **Admin → Ajustes** and are stored in the `settings` table with code defaults
(`app/models/setting.rb`).

| Variable | Purpose |
|---|---|
| `SECRET_KEY_BASE` | Rails secret in production (`bin/rails secret`). No `master.key` is needed in production. |
| `APP_HOST`, `APP_PROTOCOL` | Public host used in emails, MercadoPago return/webhook URLs and host authorization |
| `DATABASE_URL` | Primary DB; `<name>_cache`, `_queue`, `_cable` are derived (override with `*_DATABASE_URL`) |
| `STORAGE_BACKEND` | `s3` (R2/S3) or `local` |
| `S3_ENDPOINT`, `S3_REGION`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_PUBLIC_BUCKET`, `S3_PRIVATE_BUCKET` | Object storage |
| `PAYMENTS_GATEWAY` | `Payments::MercadoPagoGateway` (production default) or `Payments::FakeGateway` |
| `MERCADOPAGO_ACCESS_TOKEN`, `MERCADOPAGO_WEBHOOK_SECRET` | Fallbacks when not set in Admin → Ajustes |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Enables "Continue with Google" |
| `SMTP_*`, `MAIL_FROM`, `OPERATOR_EMAIL` | Outbound email |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | Admin created by the seeds on first boot |
| `TLS_DOMAIN` | Thruster obtains a Let's Encrypt certificate for this domain |

### Cloudflare R2 (or S3) setup
1. Create two buckets, e.g. `printremeras-public` and `printremeras-private`.
2. Public bucket: enable public access (or connect a custom domain / CDN). Private bucket: keep private — the app serves it through short-lived signed URLs.
3. Create an API token with read/write on both buckets → `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY`. `S3_ENDPOINT=https://<account_id>.r2.cloudflarestorage.com`, `S3_REGION=auto`.
4. **CORS on the private bucket** (browser uploads go straight to the bucket):
   ```json
   [{"AllowedOrigins": ["https://shop.example.com"], "AllowedMethods": ["PUT", "GET"],
     "AllowedHeaders": ["Content-Type", "Content-MD5", "Content-Disposition"], "MaxAgeSeconds": 3600}]
   ```

### MercadoPago
1. Create an application at https://www.mercadopago.com.ar/developers → get the **production access token**.
2. Enter it in Admin → Ajustes → Pagos (or `MERCADOPAGO_ACCESS_TOKEN`).
3. Webhooks: in the MercadoPago app configure the URL `https://<APP_HOST>/webhooks/mercadopago`
   for the *Payments* topic and copy the secret into `mercadopago_webhook_secret` (signature is verified when set).
   The preference also carries `notification_url`, so payments created by the app notify this URL even without global config.
4. Test with the sandbox token and MercadoPago's test users; set `PAYMENTS_GATEWAY=Payments::MercadoPagoGateway` in a staging `.env`.
   For local webhook testing expose Rails with a tunnel (ngrok hosts are allowed in development) and set `APP_HOST` accordingly.

### Google OAuth
Google Cloud Console → OAuth client (Web) → authorized redirect URI `https://<APP_HOST>/auth/google_oauth2/callback` (and `http://localhost:5173/auth/google_oauth2/callback` for dev).

---

## 3. Deployment (Docker)

The image is self-contained: Node builds the storefront, Rails serves it plus the admin,
Puma runs behind [Thruster](https://github.com/basecamp/thruster) (HTTP/2, asset caching, optional TLS).

```bash
cp .env.example .env         # set SECRET_KEY_BASE, APP_HOST, POSTGRES_PASSWORD, S3_*, MERCADOPAGO_*, SMTP_*, ADMIN_*
docker compose up -d --build # db + web (port 80/443) + worker
docker compose logs -f web
```
Generate the secret with `bin/rails secret`. Values in `.env` must not carry trailing
comments on the same line, because Docker Compose keeps them as part of the value.
`.env` is the file the containers receive; `.env.development` overrides it for local
development only and is never read by Compose. Without `SMTP_*`, notification jobs
fail visibly in Admin → Jobs rather than silently dropping mail.

**Running Docker on macOS.** Docker Desktop is not required; Colima is lighter and needs
no licence:
```bash
brew install colima docker docker-compose
mkdir -p ~/.docker/cli-plugins && ln -sfn /opt/homebrew/opt/docker-compose/bin/docker-compose ~/.docker/cli-plugins/docker-compose
colima start --cpu 4 --memory 6 --disk 40   # once per machine; `colima stop` to reclaim resources
```
To try the stack locally over plain HTTP, set `FORCE_SSL=false`, `ASSUME_SSL=false`,
`APP_HOST=localhost` and `HTTP_BIND=8080` in `.env`, then open http://localhost:8080.
First boot runs `db:prepare` (creates the four databases, loads schemas, migrates, seeds the admin).
Set `TLS_DOMAIN=shop.example.com` to get automatic HTTPS from Thruster; behind your own reverse
proxy leave it unset and proxy to port 80 (the app assumes SSL upstream: `ASSUME_SSL=true`).

Routine operations:
```bash
docker compose exec web bin/rails db:seed              # (re)create admin from ADMIN_EMAIL/ADMIN_PASSWORD
docker compose exec web bin/rails console
docker compose exec web bin/rails db:migrate           # after pulling a new version (also runs on boot)
docker compose up -d --build                           # deploy a new version (zero-config rolling restart)
docker compose exec db pg_dump -U printremeras printremeras > backup.sql
```
Scaling: raise `RAILS_MAX_THREADS` / `WEB_CONCURRENCY` for web, `JOB_CONCURRENCY` for the worker, or run several
`worker` replicas. Recurring jobs (guest purge, review invitations, Solid Queue cleanup) are in `config/recurring.yml`
and run inside the worker. Failed jobs are visible (and retryable) in Admin → Jobs.

Health check: `GET /up`. Logs go to stdout (`RAILS_LOG_LEVEL`).

### Continuous integration and GitLab

`.gitlab-ci.yml` runs the Rails suite and the frontend build on every push. Railway has no
native GitLab integration, so deployment happens through its CLI: add the `RAILWAY_TOKEN`
and `RAILWAY_SERVICE` CI/CD variables and trigger the `deploy:railway` job, which is manual
until you choose otherwise. The alternative is mirroring the repository to GitHub
(GitLab → Settings → Repository → Mirroring repositories) and letting Railway watch that,
which gives automatic deploys and one-click rollbacks with no pipeline to maintain.

### Deploying without Docker
Any Ruby host works: `bundle install --without development test`, `cd frontend && npm ci && npm run build`,
`bin/rails assets:precompile`, `bin/rails db:prepare`, run `bin/thrust bin/rails server` and `bin/jobs`.

---

## 4. Project layout

```
app/
  controllers/api/v1/     JSON API for the storefront (cookie session, CSRF header)
  controllers/admin/      server-rendered admin (operators + admins)
  controllers/webhooks/   payment provider webhooks (respond 200, process in a job)
  services/<domain>/      all business logic as service objects returning Result
    identity/ catalog/ orders/ coupons/ inventory/ payments/ shipping/ notifications/
    reviews/ messaging/ rendering/ storage/
  jobs/                   background jobs incl. DomainEvents::DispatchJob
  models/                 validations + associations only (no side effects)
  serializers/            API response shapes
  mailers/, views/        admin views, mail templates (es/ru)
lib/domain_events.rb      event bus; lib/adapters.rb adapter registry; lib/money.rb
config/initializers/domain_events.rb   event subscriptions
frontend/                 React app (src/api/client.ts, src/components/editor, src/pages, src/locales)
docs/                     ARCHITECTURE.md, DECISIONS.md
```
