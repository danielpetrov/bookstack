# Internal Knowledge Base

Self-hosted BookStack — internal wiki for the team (use cases, troubleshooting, support playbooks, architecture, integrations, FAQ).

- **Auth**: local email + password accounts only (configurable later for SSO).
- **Storage**: MariaDB (page content + revisions) and a Docker volume (uploads).
- **Hosting**: Docker Compose locally; will move to a VPS later.

---

## ⚡ Quick Start

```bash
# 1. Clone and enter the repo
git clone <repo-url> bookstack && cd bookstack

# 2. Create .env and generate secrets (requires openssl / Git Bash on Windows)
cp .env.example .env
bash scripts/gen-secrets.sh   # prints values → paste them into .env

# 3. Run everything
bash scripts/start.sh
```

> **Windows (PowerShell)?** Use Git Bash for `bash` commands, or WSL2. Docker Desktop itself runs fine in PowerShell.

---

## 0. Prerequisites

You need **Docker Desktop** installed. WSL2 backend is the default and recommended on Windows 11.

1. Download: https://www.docker.com/products/docker-desktop/
2. Run the installer. Reboot if prompted.
3. Open Docker Desktop → wait for the whale icon in the tray to settle (green = running).
4. Verify in a terminal:

   ```bash
   docker --version
   docker compose version
   ```

   Both commands must print versions without errors.

---

## 1. First boot (local)

From the repo root (`bookstack/`):

```bash
docker compose up -d
```

Docker will pull `mariadb:11.4` and `lscr.io/linuxserver/bookstack:latest` (~500 MB first time). MariaDB starts first; BookStack waits for the healthcheck, then auto-migrates the schema. **First boot takes ~60-90 seconds.**

Watch progress:

```bash
docker compose logs -f app
```

You will see Laravel migrations run. When you see something like `Server started` or `nginx ... ready` → it's up.

Open: **http://localhost:6875**

Default credentials (change immediately on first login):

| Field | Value |
| --- | --- |
| Email | `admin@admin.com` |
| Password | `password` |

After logging in:

1. Go to **Settings → Users** (top right menu).
2. Edit the `admin@admin.com` user — change email to your real one, set a strong password.
3. Log out, log in again with the new credentials.

---

## 2. Day-to-day commands

| Action | Command |
| --- | --- |
| Start | `docker compose up -d` |
| Stop | `docker compose stop` |
| Stop + remove containers (data persists in volumes) | `docker compose down` |
| Restart only BookStack | `docker compose restart app` |
| Tail logs | `docker compose logs -f app` |
| Update to newer image | `docker compose pull && docker compose up -d` |
| Open a shell in the app container | `docker compose exec app bash` |
| Run an artisan command | `docker compose exec app php /app/www/artisan <cmd>` |

---

## 3. Initial content structure (suggested)

After first login, create these **shelves** (Settings → Shelves → New Shelf):

1. **Onboarding** — getting started for new joiners
2. **Use Cases** — concrete product scenarios
3. **Troubleshooting** — common failure modes + fixes
4. **Support Playbooks** — step-by-step support runbooks
5. **Architecture** — diagrams, ADRs, system shape
6. **Integrations** — third-party hookups, API contracts
7. **FAQ / Known Issues** — short-form answers
8. **Release Notes** *(optional)*

Inside each shelf, create books for sub-topics. Inside books, chapters and pages.

Page templates (use case / troubleshooting / runbook / ADR) — we'll add these once the stack is up and verified.

---

## 4. Adding users (local accounts)

Self-registration is disabled. To add a teammate:

1. Settings → Users → **Add new user**
2. Set name, email, password (or send them an invite once SMTP is wired).
3. Assign a role: `Admin` / `Editor` / `Viewer` (or a custom role you create under Settings → Roles).
4. Share credentials securely (1Password / Bitwarden / signal).

> When we move to production we'll wire SMTP and use the **invite** flow instead.

---

## 5. Backup

Volumes are persistent — `docker compose down` does NOT delete data; `docker compose down -v` DOES (don't run with `-v` unless you mean it).

To take a manual backup:

```bash
bash scripts/backup.sh
```

This writes a timestamped folder under `backups/` with `db.sql.gz` and `uploads.tar.gz`. The folder is `.gitignored`.

**For production we'll cron this + push to Backblaze B2 / Cloudflare R2.**

To restore on a fresh stack:

```bash
# 1. Restore DB
gunzip -c backups/<stamp>/db.sql.gz | docker compose exec -T db \
  mariadb -u root -p"$DB_ROOT_PASSWORD" bookstack

# 2. Restore uploads
docker run --rm \
  -v bookstack_app_data:/data \
  -v "$(pwd)/backups/<stamp>:/backup" \
  alpine sh -c "cd /data && tar -xzf /backup/uploads.tar.gz"
```

---

## 6. Secrets

`.env` is **gitignored**. Initial values were generated with `openssl rand`. If you need to rotate them:

```bash
bash scripts/gen-secrets.sh
```

> Rotating `APP_KEY` invalidates all existing user sessions and breaks any data BookStack encrypted with the old key (mostly some 2FA secrets). Rotating DB passwords requires updating both the DB user and the env in one go — easier to just wipe and reseed for a local dev stack.

---

## 7. Troubleshooting first-boot

| Symptom | Cause | Fix |
| --- | --- | --- |
| `docker compose up -d` errors with "port 6875 already allocated" | Another process is using 6875 | Change the host-side port in `docker-compose.yml` (`"8080:80"`) and update `APP_URL` to match |
| Browser redirects in a loop on login | `APP_URL` doesn't match what you typed in the browser | Set `APP_URL` in the compose file to the exact URL you use (incl. scheme + port), then `docker compose up -d` |
| `app` container exits immediately | Likely DB not ready or wrong password | `docker compose logs db` then `docker compose logs app`. If `MARIADB_PASSWORD` mismatch, `docker compose down -v` then `up -d` again (wipes data) |
| Can log in but "An error occurred" on every page | `APP_KEY` missing or wrong format | Make sure `.env` has `APP_KEY=base64:...` (44 chars after the prefix) |
| "Database is upgrading" forever | Stuck migration | `docker compose exec app php /app/www/artisan migrate --force` |

---

## 8. What's next (planned)

- [ ] Verify clean first boot
- [ ] Change default admin
- [ ] Seed the 7 shelves
- [ ] Create page templates (use case / troubleshooting / runbook / ADR)
- [ ] Move to a Hetzner VPS with Caddy + Let's Encrypt
- [ ] DNS for `kb.company.com`
- [ ] Cloudflare Access (or simple login-walled) for off-network access
- [ ] Cron the backup script + push to Backblaze B2
- [ ] Wire SMTP (Resend / SendGrid) for invites & password reset

Track progress in commits.
