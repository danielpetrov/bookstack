#!/usr/bin/env bash
# Regenerate APP_KEY and DB passwords. Prints to stdout; you copy them into .env.
# Run again only if you intend to invalidate existing sessions / wipe the stack.
set -euo pipefail

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl not found. Install OpenSSL or run from Git Bash on Windows." >&2
  exit 1
fi

echo "APP_KEY=base64:$(openssl rand -base64 32)"
echo "DB_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/' | head -c 32)"
echo "DB_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/' | head -c 32)"
