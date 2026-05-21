#!/usr/bin/env bash
# Back up BookStack: MariaDB dump + uploads volume.
# Run from the repo root:  bash scripts/backup.sh
#
# Output goes to ./backups/<YYYY-MM-DD_HHMM>/
# These artefacts are .gitignored. For production push them off-site
# (Backblaze B2 / Cloudflare R2 / S3) with rclone in a separate step.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo ".env not found in repo root" >&2
  exit 1
fi

# shellcheck disable=SC1091
source .env

STAMP=$(date +%Y-%m-%d_%H%M)
OUT="backups/${STAMP}"
mkdir -p "$OUT"

echo "[1/2] Dumping MariaDB to ${OUT}/db.sql.gz"
docker compose exec -T db \
  mariadb-dump -u root -p"${DB_ROOT_PASSWORD}" --single-transaction --quick bookstack \
  | gzip > "${OUT}/db.sql.gz"

echo "[2/2] Tarring uploads volume to ${OUT}/uploads.tar.gz"
# Spin up a throwaway alpine container that mounts the named volume, then tars it.
docker run --rm \
  -v internal-kb_app_data:/data:ro \
  -v "$(pwd)/${OUT}:/backup" \
  alpine \
  sh -c "cd /data && tar -czf /backup/uploads.tar.gz ."

echo "Done: ${OUT}"
du -sh "${OUT}"/*
