#!/usr/bin/env bash
# gitleaks-scan.sh — Install gitleaks and scan repo for secrets.
# Usage: ./gitleaks-scan.sh [repo-path]
# Returns exit 0 if 0 findings, exit 1 if any secrets found.
set -euo pipefail

REPO="${1:-.}"
REPORT="/tmp/gitleaks-$(date +%Y%m%d-%H%M%S).json"
GITLEAKS_VER="8.21.2"

# Install if not present
if ! command -v gitleaks &>/dev/null; then
  echo "Installing gitleaks v${GITLEAKS_VER}..."
  curl -sL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VER}/gitleaks_${GITLEAKS_VER}_linux_x64.tar.gz" \
    | tar xz -C /usr/local/bin gitleaks
fi

gitleaks detect \
  --source "$REPO" \
  --report-format json \
  --report-path "$REPORT" \
  --redact \
  --exit-code 1

COUNT=$(jq 'length' "$REPORT" 2>/dev/null || echo 0)
echo "gitleaks: $COUNT finding(s). Report: $REPORT"
[ "$COUNT" -eq 0 ] || { echo "FAIL: $COUNT secret(s) found — see $REPORT"; exit 1; }
echo "PASS: 0 findings."
