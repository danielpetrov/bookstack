#!/usr/bin/env bash
# Back up the Nextcloud KB: MariaDB dump + the entire Nextcloud data volume.
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

echo "[1/3] Putting Nextcloud into maintenance mode"
docker compose exec -u www-data -T app php occ maintenance:mode --on || true

echo "[2/3] Dumping MariaDB to ${OUT}/db.sql.gz"
docker compose exec -T db \
  mariadb-dump -u root -p"${DB_ROOT_PASSWORD}" --single-transaction --quick nextcloud \
  | gzip > "${OUT}/db.sql.gz"

echo "[3/3] Tarring Nextcloud data volume to ${OUT}/data.tar.gz"
# The Compose project is named "kb" (see top of docker-compose.yml),
# so the named volume is kb_app_data.
docker run --rm \
  -v kb_app_data:/data:ro \
  -v "$(pwd)/${OUT}:/backup" \
  alpine \
  sh -c "cd /data && tar -czf /backup/data.tar.gz ."

echo "Releasing maintenance mode"
docker compose exec -u www-data -T app php occ maintenance:mode --off || true

echo "Done: ${OUT}"
du -sh "${OUT}"/* 2>/dev/null || true
