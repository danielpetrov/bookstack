#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# start.sh — Start the BookStack internal knowledge base
# Run from anywhere:  bash scripts/start.sh
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
ENV_FILE="$ROOT_DIR/.env"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        📚  BookStack Launcher                    ║"
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
  echo "    cp .env.example .env"
  echo "    bash scripts/gen-secrets.sh   # generates values to paste in"
  exit 1
fi

# ── Validate required keys are set ───────────────────────────────────────────
for KEY in APP_KEY DB_ROOT_PASSWORD DB_PASSWORD; do
  VALUE=$(grep -oP "(?<=${KEY}=)\S+" "$ENV_FILE" | head -1 || true)
  if [ -z "$VALUE" ] || [ "$VALUE" = "REPLACE_ME" ]; then
    echo "❌  $KEY is not set in .env — run: bash scripts/gen-secrets.sh"
    exit 1
  fi
done

# ── Pull latest images ────────────────────────────────────────────────────────
echo "📦  Pulling latest images..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull --quiet

# ── Start all containers ──────────────────────────────────────────────────────
echo "🚀  Starting containers..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --remove-orphans

# ── Wait for BookStack to be ready ───────────────────────────────────────────
echo "⏳  Waiting for BookStack to be ready (up to 90s)..."
TRIES=0
until curl -s -o /dev/null -w "%{http_code}" http://localhost:6875 | grep -qE '^[23]'; do
  TRIES=$((TRIES + 1))
  if [ "$TRIES" -ge 18 ]; then
    echo "⚠️   Still starting — check logs: docker compose logs -f app"
    break
  fi
  sleep 5
done

# ── Print results ─────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  ✅  BookStack is running!                       ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  🏠  Local:  http://localhost:6875               ║"
echo "║  👤  Login:  admin@admin.com / password          ║"
echo "║             ↑ change these immediately!          ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  📋  Useful commands:                            ║"
echo "║      docker compose logs -f app  (app logs)     ║"
echo "║      docker compose ps           (status)       ║"
echo "║      docker compose stop         (pause)        ║"
echo "║      docker compose down         (stop all)     ║"
echo "║      bash scripts/backup.sh      (backup now)   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
