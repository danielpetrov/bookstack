# Internal Knowledge Base

> Self-hosted Nextcloud + Collabora Online — internal document hub and wiki
> for the team. Upload PDFs / Word / Excel and **view & edit them in the
> browser**, alongside markdown wiki pages. Local-first dev, moves to a small
> VPS for production.

**Stack:** Nextcloud 30 · Collabora Online (CODE) · MariaDB 11 · Redis 7 · Docker Compose · local accounts auth

---

## Contents

1. [What this is](#1-what-this-is)
2. [What you get out of the box](#2-what-you-get-out-of-the-box)
3. [Architecture at a glance](#3-architecture-at-a-glance)
4. [Quick start (TL;DR)](#4-quick-start-tldr)
5. [Prerequisites](#5-prerequisites)
6. [First-time setup, step by step](#6-first-time-setup-step-by-step)
7. [Day-to-day usage](#7-day-to-day-usage)
    - [The mental model](#71-the-mental-model)
    - [Uploading files](#72-uploading-files)
    - [Opening & editing documents in the browser](#73-opening--editing-documents-in-the-browser)
    - [Custom wiki-style pages (Collectives app)](#74-custom-wiki-style-pages-collectives-app)
    - [Sharing content](#75-sharing-content)
    - [Searching](#76-searching)
    - [Tags](#77-tags)
    - [Sync clients (desktop & mobile)](#78-sync-clients-desktop--mobile)
8. [User and permission management](#8-user-and-permission-management)
9. [Backup and restore](#9-backup-and-restore)
10. [Updating Nextcloud](#10-updating-nextcloud)
11. [Command cheatsheet](#11-command-cheatsheet)
12. [Troubleshooting](#12-troubleshooting)
13. [Secrets](#13-secrets)
14. [Project layout](#14-project-layout)
15. [Roadmap](#15-roadmap)

---

## 1. What this is

A working Nextcloud + Collabora Online setup you run locally with one
command, then later promote to a small VPS with TLS and access control.

Unlike a pure wiki tool, this stack treats **uploaded documents as
first-class content**: you can upload a PDF and read it in-browser, upload a
`.docx` and edit it collaboratively in-browser, alongside markdown wiki
pages. All of it is searchable, shareable, version-tracked, and ACL-aware.

**Why this stack:**

- **Nextcloud** — file management, sharing, ACL, versioning, search, mobile/desktop sync clients
- **Collabora Online (CODE)** — in-browser PDF / Word / Excel / PowerPoint viewing **and** real-time multi-cursor editing
- **Collectives app** (installed in Nextcloud) — markdown-based wiki pages with linked navigation
- All open-source, self-hostable, single docker-compose

---

## 2. What you get out of the box

### File management
| Capability | Included |
| --- | --- |
| Drag-and-drop upload of any file type | Yes |
| Folder hierarchy with per-folder permissions | Yes |
| In-browser PDF viewer | Yes (Nextcloud native) |
| In-browser image / video / audio preview | Yes |
| In-browser `.docx` / `.xlsx` / `.pptx` viewing **and** editing | Yes (via Collabora) |
| Real-time multi-cursor editing of Office docs | Yes (Collabora) |
| File versioning with restore | Yes |
| Tags + comments on files | Yes |
| Activity feed (who did what) | Yes |
| Full-text search inside documents | Yes (Nextcloud Full Text Search app) |
| Trash / recycle bin | Yes |

### Wiki / custom pages
| Capability | Included |
| --- | --- |
| Markdown pages organised in nested "collectives" | Yes (Collectives app) |
| Page-level permissions | Yes |
| Live preview while editing | Yes |
| Mermaid diagrams, callouts, mentions | Yes |
| Page revisions | Yes |

### Sharing & access
| Capability | Included |
| --- | --- |
| Local user accounts (email + password) | Yes (configured) |
| Group-based ACL | Yes |
| Share with a specific user | Yes |
| Public link share with optional password + expiry + download counter | Yes |
| External share without account | Yes |
| Federated sharing (between Nextcloud instances) | Available |
| SSO (Google / Microsoft / SAML / LDAP) | Available, deferred |

### Operations
| Capability | Included |
| --- | --- |
| Backup script (DB + data volume) | Yes |
| Maintenance mode toggle | Yes |
| `occ` admin CLI | Yes |
| Mobile / desktop sync clients | Yes (download separately) |

---

## 3. Architecture at a glance

```
   Browser
       │
       ├──► http://localhost:8080  (Nextcloud — files & UI)
       │
       └──► http://localhost:9980  (Collabora — Office editor iframe)

   ┌────────────────────────────────────────────────────────┐
   │  Docker network: kb_default                            │
   │                                                        │
   │   ┌─────────────┐    ┌─────────────┐   ┌────────────┐ │
   │   │  kb-app     │◄──►│  kb-db      │   │ kb-redis   │ │
   │   │  Nextcloud  │    │  MariaDB    │   │ Redis 7    │ │
   │   │  Apache+PHP │    │  11.4       │   │ sessions   │ │
   │   └──────┬──────┘    └─────────────┘   │ + cache    │ │
   │          │                              └────────────┘ │
   │          │ WOPI                                        │
   │          ▼                                             │
   │   ┌──────────────────┐                                 │
   │   │  kb-collabora    │   Document editor server        │
   │   │  collabora/code  │   (PDF.js + LibreOffice core)   │
   │   └──────────────────┘                                 │
   │                                                        │
   │   Persistent volumes:                                  │
   │     app_data    — Nextcloud code, config, USER FILES   │
   │     db_data     — MariaDB data dir                     │
   │     redis_data  — Redis persistence                    │
   └────────────────────────────────────────────────────────┘
```

- **`kb-app`** runs Nextcloud (PHP/Apache) — the UI and file API.
- **`kb-db`** holds users, groups, permissions, file metadata, comments, activity.
- **`kb-redis`** caches sessions and handles file locking.
- **`kb-collabora`** renders PDFs in-browser and serves the Office editor.
- **`app_data`** is where your actual uploaded files live (inside `data/`).
- The four volumes are the only place your data lives. Lose them, you lose
  everything. Back them up (see [§9](#9-backup-and-restore)).

---

## 4. Quick start (TL;DR)

```bash
# 1. Generate secrets (Git Bash on Windows, or any shell with openssl)
bash scripts/gen-secrets.sh > .env

# 2. Start the whole stack with the launcher
bash scripts/start.sh

# 3. When the launcher prints "Nextcloud is running":
#    Open  http://localhost:8080
#    Log in with the username/password the script printed
```

That's it. The rest of this README is reference.

---

## 5. Prerequisites

You need **Docker Desktop** for Windows or macOS, or `docker` + `docker
compose` on Linux. On Windows 11 it uses WSL 2 — accept the default
during install.

1. Download from <https://www.docker.com/products/docker-desktop/>.
2. Run the installer. Reboot if prompted.
3. Open Docker Desktop and wait for the whale icon in the tray to settle.
   Green = running.
4. Verify in a terminal (Git Bash, PowerShell, or Terminal):

   ```bash
   docker --version
   docker compose version
   ```

### Resource recommendation

| Hardware | Verdict |
| --- | --- |
| 16 GB RAM, 4+ cores | Comfortable for the full stack including Collabora |
| 8 GB RAM | Works but feels tight when Office docs are open; consider stopping Collabora when not needed |
| < 8 GB RAM | Not recommended |

The stack idles at ~2.5 GB RAM and uses CPU bursts when documents are
opened or saved.

---

## 6. First-time setup, step by step

### 6.1 Generate secrets

```bash
cd /c/Users/DanielPetrov/Desktop/Work/internal-kb
bash scripts/gen-secrets.sh > .env
```

This writes a gitignored `.env` with three random secrets and the admin
username (`admin`).

### 6.2 Boot the stack

```bash
bash scripts/start.sh
```

The launcher:
- Verifies Docker is up
- Validates `.env` keys are set
- Pulls images (~1.5 GB first time)
- Brings up four containers (`db`, `redis`, `app`, `collabora`)
- Waits for `http://localhost:8080/status.php` to respond
- Prints the URL + admin credentials

First boot takes 2–3 minutes (Nextcloud initialises the DB schema on first
run, which is the slow part).

### 6.3 First login

Open <http://localhost:8080>.

Credentials are the ones printed by `start.sh`. They're also stored in
`.env` under `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`.

Once in:

1. Top-right avatar → **Personal settings** → set your real name + email.
2. **Security** → enable 2FA (TOTP via Authy / Bitwarden / 1Password).

### 6.4 Enable Collabora (one-time)

1. Top-right avatar → **+ Apps**.
2. Search for **Nextcloud Office** → **Download and enable**.
3. Top-right avatar → **Administration settings** → **Office**.
4. Pick **Use your own server** → URL: `http://host.docker.internal:9980`
5. Save. The "Test connection" should turn green.

Now `.docx`, `.xlsx`, `.pptx` files open in the browser with full Office
editing.

### 6.5 Enable Collectives (wiki app, optional but recommended)

1. **+ Apps** → search **Collectives** → **Download and enable**.
2. A new "Collectives" entry appears in the left nav.
3. Create your first collective ("Knowledge Base", say) — it becomes a
   wiki-style tree of markdown pages.

### 6.6 Suggested initial structure

Inside Nextcloud → **Files**, create these top-level folders:

| Folder | Purpose |
| --- | --- |
| `01 - Onboarding` | New-joiner orientation, setup, accounts |
| `02 - Use Cases` | Product scenarios with steps and outcomes |
| `03 - Troubleshooting` | Known failures and their fixes |
| `04 - Support Playbooks` | Step-by-step runbooks for support handoff |
| `05 - Architecture` | Diagrams, ADRs, design rationale |
| `06 - Integrations` | Third-party hookups, API contracts, config |
| `07 - FAQ` | Short-form answers and gotchas |
| `08 - Release Notes` *(optional)* | What changed and when |

Inside each folder, mix uploaded PDFs/Office docs with custom markdown
files (`.md`) as needed. Use Collectives separately for structured wiki
content where you want cross-page linking.

---

## 7. Day-to-day usage

### 7.1 The mental model

Two complementary content surfaces:

| Surface | Best for | Example |
| --- | --- | --- |
| **Files** (folders + uploads) | Documents you receive or produce — PDFs, Word, Excel, diagrams, archives | Vendor SOWs, exported reports, signed contracts, raw screenshots |
| **Collectives** (markdown wiki) | Living team knowledge that you author from scratch | Runbooks, ADRs, FAQs, onboarding guides |

You can interlink them: a Collective page can embed or link to files in
the Files area, and vice versa.

### 7.2 Uploading files

| You want to | How |
| --- | --- |
| Upload one or many files | Drag from desktop onto the Files page |
| Upload a folder | Drag the folder; structure is preserved |
| Upload from the URL bar | **+ New → Upload file** |
| Create a file in-browser | **+ New → New document / spreadsheet / presentation / Plain text** |
| Resume a big upload | Nextcloud chunks uploads automatically — refresh and re-drop the same file |

Default per-file upload limit is 512 MB (set via `PHP_UPLOAD_LIMIT` in the
compose). Raise it in `docker-compose.yml` if you need to attach larger
binaries.

### 7.3 Opening & editing documents in the browser

| File type | What happens when you click | Editable in-browser |
| --- | --- | --- |
| `.pdf` | Opens in PDF.js viewer (zoom, search, print) | View only |
| `.docx`, `.odt` | Opens in Collabora — full Word-style editor | Yes (collaborative) |
| `.xlsx`, `.ods` | Opens in Collabora — full Excel-style editor | Yes |
| `.pptx`, `.odp` | Opens in Collabora — full PowerPoint editor | Yes |
| `.md` | Opens in Markdown editor with live preview | Yes |
| `.txt`, `.json`, `.yaml`, source code | Opens in the Text editor | Yes |
| `.png`, `.jpg`, `.svg`, `.webp` | Opens in image viewer | View only |
| `.mp4`, `.mp3`, `.webm` | Opens in media player | View only |

**Collaborative editing**: when two people open the same `.docx`, both
see each other's cursor in real time. Changes auto-save. The Office file
on disk reflects the latest saved state.

**Version history**: right-click a file → **Versions**. Restore any
previous version with one click. Major edits create snapshots
automatically.

### 7.4 Custom wiki-style pages (Collectives app)

A *collective* is a tree of markdown pages backed by a shared folder. The
editor is markdown with live preview, plus a navigation tree, search, and
page templates.

| You want to | How |
| --- | --- |
| Create a new collective | Collectives → **+ New collective** |
| Create a sub-page | Open a parent page → **+ Add page** |
| Link to another page | Type `[[` and start typing — autocomplete pops up |
| Embed an image | Drag-drop into the editor — uploaded to the collective's folder |
| Use a template | Open page settings → **Use a template** |
| Search | Top-bar search includes collective content |

The actual markdown files live under `Files → <collective name>/`. You
can edit them from either place — changes sync.

### 7.5 Sharing content

**Internal — share with a teammate**

1. Right-click file or folder → **Details** → **Sharing** tab.
2. Type a username; pick permission (read, edit, share, delete).
3. They see it in their **Shared with you** view immediately.

**External — share with a public link**

1. Same sharing panel → **+ Share link** → **Copy link**.
2. Click the **⋯** next to the link to configure:
   - **Read-only / allow editing / allow upload (file drop)**
   - **Password protect**
   - **Set expiration date**
   - **Hide download** (preview only)
   - **Disable downloading by viewers**
3. Send the link. Recipients don't need an account.

**Per-folder permissions for whole groups**

Settings → **Users** → create a group → assign users.
Then share a folder with the group with a chosen permission set.

### 7.6 Searching

The top-bar search is unified:

- File names
- Tags
- File **contents** (PDF, Office, markdown, text) — once the Full Text
  Search app is enabled
- Collective pages
- Activity / mentions

To enable content search:

1. **+ Apps** → search **Full text search** → enable.
2. Also enable **Full text search - Files** and **Full text search -
   Elasticsearch** *(skip Elasticsearch — uses bundled index by default)*.
3. Admin Settings → Full text search → **Index files**.

Indexing runs in the background; new uploads index automatically.

### 7.7 Tags

| Action | How |
| --- | --- |
| Add a tag to a file | Right-click → Details → Tags |
| Browse all files with a tag | Left nav → **Tags** → click a tag |
| Restrict who sees a tag | Tag visibility: public / restricted / invisible |
| Filter file list by tag | **Tags** menu in the Files header |

Useful patterns:

- `team:support` — owning team
- `status:draft` / `status:final`
- `severity:p1` — incident docs
- `client:foo` — per-client folders

### 7.8 Sync clients (desktop & mobile)

Optional but powerful — Nextcloud has native sync apps so files appear
locally on team members' machines:

- Desktop: <https://nextcloud.com/install/#install-clients> (Windows / macOS / Linux)
- Mobile: Nextcloud app in App Store / Play Store
- Settings → connect to `http://localhost:8080` (locally) or
  `https://kb.your-domain.com` (production) with the same credentials

Users get a `Nextcloud/` folder that mirrors their shared files. Edits
sync both ways.

---

## 8. User and permission management

### 8.1 Adding teammates

1. Top-right avatar → **Users** → **+ New user**.
2. Set username, name, email, password.
3. Add to one or more groups.
4. Save.

The new user can log in immediately. Share credentials securely
(Bitwarden, 1Password, Signal — not email).

> When we move to production we'll wire SMTP so Nextcloud sends a
> welcome / password-reset email instead.

### 8.2 Groups

Groups are how you batch-assign permissions:

- Create groups under **Users → Groups (left side)**.
- Assign users to groups when creating / editing them.
- When sharing, share with a group rather than each user.

Suggested initial groups:

| Group | Members |
| --- | --- |
| `team` | The 4 core team members |
| `support` | The support staff |
| `admins` | People allowed to change settings |

### 8.3 Built-in roles

Nextcloud doesn't have "roles" in the BookStack sense — instead, **group
admins** can manage their group's users, and a dedicated **admin** group
controls site settings. Per-file/folder ACL is set via the sharing UI.

### 8.4 Disabling self-registration

Off by default. Don't enable the **Registration** app unless you
explicitly want anyone to sign up — for an internal KB that's almost
always wrong.

---

## 9. Backup and restore

### 9.1 What lives where

| Data | Where | Persists across `docker compose down` |
| --- | --- | --- |
| File contents (your uploads) | `kb_app_data` volume → `/var/www/html/data/` | Yes |
| Users, groups, ACL, metadata | `kb_db_data` volume → MariaDB | Yes |
| Nextcloud config | `kb_app_data` volume → `/var/www/html/config/` | Yes |
| Sessions / cache | `kb_redis_data` volume | Yes (lossy is OK to drop) |
| Secrets | `.env` in the repo | Yes (gitignored) |

> `docker compose down -v` **deletes** the volumes. Don't run with `-v`
> unless you mean to wipe everything.

### 9.2 Manual backup

```bash
bash scripts/backup.sh
```

The script:
1. Puts Nextcloud into maintenance mode (read-only) so the DB and files
   stay consistent.
2. Dumps MariaDB to `backups/<stamp>/db.sql.gz`.
3. Tars the entire `app_data` volume to `backups/<stamp>/data.tar.gz`.
4. Releases maintenance mode.

The `backups/` folder is gitignored.

For production we cron this + push the artefacts to Backblaze B2 or
Cloudflare R2 with `rclone`.

### 9.3 Restore on a fresh stack

```bash
# Assuming a fresh `bash scripts/start.sh` against empty volumes,
# and BackupDIR=backups/2026-05-26_1432:

source .env

# 1. Put the freshly-started Nextcloud into maintenance mode
docker compose exec -u www-data app php occ maintenance:mode --on

# 2. Restore the database
gunzip -c "$BackupDIR/db.sql.gz" | \
  docker compose exec -T db \
  mariadb -u root -p"$DB_ROOT_PASSWORD" nextcloud

# 3. Restore the data + config
docker run --rm \
  -v kb_app_data:/data \
  -v "$(pwd)/$BackupDIR:/backup" \
  alpine sh -c "cd /data && tar -xzf /backup/data.tar.gz"

# 4. Release maintenance mode + restart the app
docker compose exec -u www-data app php occ maintenance:mode --off
docker compose restart app
```

---

## 10. Updating Nextcloud

```bash
docker compose pull        # fetch latest images
docker compose up -d       # recreate containers
docker compose exec -u www-data app php occ upgrade   # if prompted
docker compose logs -f app # watch for any migration output
```

Nextcloud publishes a new major version about twice a year and frequent
patch releases. Always **back up before upgrading** — once a major
version is applied, downgrading is not supported.

Read release notes at <https://nextcloud.com/changelog/>.

---

## 11. Command cheatsheet

| Action | Command |
| --- | --- |
| Start the whole stack (with checks) | `bash scripts/start.sh` |
| Start without the launcher | `docker compose up -d` |
| Stop (keep data) | `docker compose stop` |
| Stop + remove containers (keep data) | `docker compose down` |
| Stop + **wipe all data** | `docker compose down -v` |
| Restart just Nextcloud | `docker compose restart app` |
| Restart just Collabora | `docker compose restart collabora` |
| Tail Nextcloud logs | `docker compose logs -f app` |
| Tail Collabora logs | `docker compose logs -f collabora` |
| Tail DB logs | `docker compose logs -f db` |
| Pull newer images | `docker compose pull` |
| Shell into the app container | `docker compose exec app bash` |
| Run an `occ` (Nextcloud CLI) command | `docker compose exec -u www-data app php occ <cmd>` |
| List apps | `docker compose exec -u www-data app php occ app:list` |
| Enable an app | `docker compose exec -u www-data app php occ app:enable <id>` |
| Reset a user password from CLI | `docker compose exec -u www-data app php occ user:resetpassword <user>` |
| Run a backup now | `bash scripts/backup.sh` |
| Regenerate secrets | `bash scripts/gen-secrets.sh > .env` |

---

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `port 8080 already allocated` | Another service is on 8080 | Change the host port in `docker-compose.yml` and update `OVERWRITEHOST` to match |
| First boot stuck on "Initializing Nextcloud..." | DB not ready or wrong creds | `docker compose logs db` + `docker compose logs app`. If creds drifted, `docker compose down -v` + `start.sh` again (wipes data) |
| Login page loops / "Access through untrusted domain" | Browser URL not in `NEXTCLOUD_TRUSTED_DOMAINS` | Add it to the env var in compose, then `docker compose up -d` |
| Collabora connect test fails | URL mismatch | In Office settings, use `http://host.docker.internal:9980` (not `http://localhost:9980`) |
| `.docx` opens but iframe is blank | `aliasgroup1` in Collabora doesn't match Nextcloud's URL | Edit `aliasgroup1` in compose to match the URL you load Nextcloud at (e.g. `http://localhost:8080`); `docker compose up -d` |
| Searching doesn't find content inside PDFs | Full Text Search not enabled / not indexed | Apps → enable **Full text search** + **Files**; Admin → Full text search → **Index** |
| Big upload fails with 413 | Hit the body / PHP limit | Raise `PHP_UPLOAD_LIMIT` (and `client_max_body_size` if behind a proxy) |
| Sync client says "untrusted certificate" | Local dev uses HTTP, sync clients want HTTPS | Use sync clients only after we set up TLS on production |
| Nextcloud says "PHP modules missing" in admin overview | Optional perf extension absent | Safe to ignore for local dev; we'll resolve in the production image |

If a fix isn't here, check the logs first:

```bash
docker compose logs --tail 200 app
docker compose logs --tail 100 collabora
docker compose logs --tail 100 db
```

Then the Nextcloud admin manual at <https://docs.nextcloud.com/server/30/admin_manual/>.

---

## 13. Secrets

`.env` is **gitignored**. Initial values were generated with `openssl
rand`.

To rotate them, regenerate and overwrite:

```bash
bash scripts/gen-secrets.sh > .env
```

Then recreate the containers so they pick up the new env:

```bash
docker compose down
bash scripts/start.sh
```

> **Be careful rotating the DB password in-place.** The MariaDB image
> uses the value at first init; later changes need an `ALTER USER` inside
> the DB. For a local dev stack it's easier to `down -v` + restart from a
> clean state.

> The initial **Nextcloud admin password** in `.env` only matters on
> first boot. After Nextcloud creates the admin user, change it through
> the UI; rotating it in `.env` later has no effect on the existing
> account.

---

## 14. Project layout

```
internal-kb/
├── docker-compose.yml      Stack definition: db + redis + app + collabora
├── .env                    Generated secrets (gitignored)
├── .env.example            Template + instructions for filling in .env
├── .gitignore              Keeps secrets, backups, IDE noise out of git
├── README.md               This file
├── scripts/
│   ├── start.sh            Launcher: validates env, pulls, boots, prints URL + creds
│   ├── gen-secrets.sh      Regenerate DB and admin passwords
│   └── backup.sh           Maintenance-mode-safe DB + data volume backup
└── backups/                (created on first backup; gitignored)
```

---

## 15. Roadmap

Local dev:

- [x] Docker Compose stack: MariaDB + Redis + Nextcloud + Collabora
- [x] Local accounts auth (no SSO yet)
- [x] Secrets generated, gitignored
- [x] Backup script (maintenance-mode safe)
- [x] One-command launcher (`scripts/start.sh`)
- [ ] First boot verified
- [ ] Nextcloud Office app installed + Collabora URL set
- [ ] Collectives app installed
- [ ] Full Text Search app installed + initial index
- [ ] Suggested folder structure seeded
- [ ] `team` / `support` / `admins` groups created
- [ ] First user added (besides admin)

Production:

- [ ] Hetzner CX31 (8 GB RAM) VPS provisioned
- [ ] Docker installed; non-root deploy user
- [ ] Caddy reverse proxy with Let's Encrypt TLS
- [ ] DNS for `kb.<your-domain>`
- [ ] Cloudflare Access (or simple login-walled) for off-network protection
- [ ] Daily backup cron + push to Backblaze B2 / Cloudflare R2
- [ ] SMTP wired (Resend / SendGrid) for invites and password reset
- [ ] UptimeRobot ping on the public URL
- [ ] Trusted domains and `OVERWRITEPROTOCOL=https` set for prod
- [ ] Collabora `aliasgroup1` pointed at production HTTPS URL

Track progress in commits.

---

*Internal use only. Not for external distribution.*
