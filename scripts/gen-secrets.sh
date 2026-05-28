#!/usr/bin/env bash
# Regenerate secrets for the Nextcloud KB stack.
# Prints to stdout — redirect into .env:
#   bash scripts/gen-secrets.sh > .env
set -euo pipefail

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl not found. Install OpenSSL or run from Git Bash on Windows." >&2
  exit 1
fi

echo "DB_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/' | head -c 32)"
echo "DB_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/' | head -c 32)"
echo "NEXTCLOUD_ADMIN_USER=admin"
echo "NEXTCLOUD_ADMIN_PASSWORD=$(openssl rand -base64 18 | tr -d '=+/' | head -c 24)"
