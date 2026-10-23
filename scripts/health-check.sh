#!/usr/bin/env bash
# health-check.sh — Poll an HTTP endpoint until it responds 200 or timeout.
# Usage: ./health-check.sh <url> [max_attempts]
# Placeholders: replace <APP_HOST> and <PORT> with your values.
set -euo pipefail

URL="${1:-http://127.0.0.1:<PORT>/health}"
MAX="${2:-30}"

for i in $(seq 1 "$MAX"); do
  if curl -sf "$URL" -o /dev/null; then
    echo "Service healthy at $URL (attempt $i)"
    exit 0
  fi
  echo "Waiting... ($i/$MAX)"
  sleep 1
done

echo "ERROR: Service did not become healthy at $URL after $MAX attempts" >&2
exit 1
