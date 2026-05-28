#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# start.sh — Start the Nextcloud internal knowledge base
# Run from anywhere:  bash scripts/start.sh
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
ENV_FILE="$ROOT_DIR/.env"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║       ☁️   Nextcloud KB Launcher                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Check Docker is running ───────────────────────────────────────────────────
if ! docker info > /dev/null 2>&1; then
  echo "❌  Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

# ── Check .env exists ─────────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  echo "❌  .env file not found. Create one first:"
  echo "    bash scripts/gen-secrets.sh > .env"
  exit 1
fi

# ── Validate required keys are set ────────────────────────────────────────────
for KEY in DB_ROOT_PASSWORD DB_PASSWORD NEXTCLOUD_ADMIN_PASSWORD; do
  VALUE=$(grep -oP "(?<=${KEY}=)\S+" "$ENV_FILE" | head -1 || true)
  if [ -z "$VALUE" ] || [ "$VALUE" = "REPLACE_ME" ]; then
    echo "❌  $KEY is not set in .env — run: bash scripts/gen-secrets.sh > .env"
    exit 1
  fi
done

ADMIN_USER=$(grep -oP "(?<=NEXTCLOUD_ADMIN_USER=)\S+" "$ENV_FILE" | head -1 || echo "admin")
ADMIN_PASS=$(grep -oP "(?<=NEXTCLOUD_ADMIN_PASSWORD=)\S+" "$ENV_FILE" | head -1)

# ── Pull latest images ────────────────────────────────────────────────────────
echo "📦  Pulling latest images (first run downloads ~1.5 GB)..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull --quiet

# ── Start all containers ──────────────────────────────────────────────────────
echo "🚀  Starting containers (db, redis, app, collabora)..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --remove-orphans

# ── Wait for Nextcloud to be ready ────────────────────────────────────────────
echo "⏳  Waiting for Nextcloud to be ready (first boot can take 2–3 minutes)..."
TRIES=0
until curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/status.php 2>/dev/null | grep -qE '^[23]'; do
  TRIES=$((TRIES + 1))
  if [ "$TRIES" -ge 36 ]; then
    echo "⚠️   Still starting — check logs with:  docker compose logs -f app"
    break
  fi
  sleep 5
done

# ── Print results ─────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Nextcloud is running!                                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  🏠  URL:        http://localhost:8080"
echo "  👤  Username:   $ADMIN_USER"
echo "  🔑  Password:   $ADMIN_PASS"
echo ""
echo "  📝  Collabora Office (for editing .docx / .xlsx / .pptx in-browser)"
echo "      runs on    http://localhost:9980"
echo ""
echo "      After first login enable it once:"
echo "        1. Apps → search \"Nextcloud Office\" → Install"
echo "        2. Admin Settings → Office → \"Use your own server\""
echo "           URL: http://host.docker.internal:9980"
echo "        3. Save. .docx / .xlsx files now open in-browser."
echo ""
echo "  📋  Useful commands:"
echo "      docker compose logs -f app   (app logs)"
echo "      docker compose ps            (status)"
echo "      docker compose stop          (pause)"
echo "      docker compose down          (stop all — data persists)"
echo "      bash scripts/backup.sh       (backup DB + files now)"
echo ""
