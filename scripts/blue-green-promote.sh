#!/usr/bin/env bash
# blue-green-promote.sh — Atomic Nginx swap between blue and green slots.
# Prerequisites:
#   - /etc/app/.active-colour contains "blue" or "green"
#   - Nginx upstream names are "app-blue" and "app-green"
#   - Run as root or with sudo
# Placeholders: replace <NGINX_CONF>, <ACTIVE_COLOUR_FILE> with real paths.
set -euo pipefail

ACTIVE_FILE="${ACTIVE_COLOUR_FILE:-/etc/app/.active-colour}"
NGINX_CONF="${NGINX_CONF:-/etc/nginx/conf.d/app.conf}"

ACTIVE=$(cat "$ACTIVE_FILE")
NEW=$( [ "$ACTIVE" = "blue" ] && echo "green" || echo "blue" )

echo "Promoting: $ACTIVE → $NEW"

# Swap upstream reference
sed -i "s/app-${ACTIVE}/app-${NEW}/g" "$NGINX_CONF"

# Validate and reload (atomic — no connection drops)
nginx -t || { echo "nginx config invalid — reverting"; sed -i "s/app-${NEW}/app-${ACTIVE}/g" "$NGINX_CONF"; exit 1; }
systemctl reload nginx

echo "$NEW" > "$ACTIVE_FILE"
echo "Done. Active colour is now $NEW. Old colour $ACTIVE is still warm."
echo "To rollback: run this script again (it will swap back to $ACTIVE)."
