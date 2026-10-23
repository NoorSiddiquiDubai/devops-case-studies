# Case Study 02 — Blue/Green Auto-Failover

## Problem

A Node.js API service (port 9101 = blue, port 9103 = green) ran behind Nginx as a reverse proxy. Deploys required a manual `systemctl restart` of the active colour, producing ~3 s of 502 downtime visible to end users. Weekend deploys were skipped to avoid risk, causing a 2-week deploy queue.

## Action

1. **Defined two systemd units** (`api-blue.service`, `api-green.service`) pointing at the same codebase directory symlinked to the active release snapshot. Each unit binds to its own port; Nginx upstream selects the active colour from `/etc/app/.active-colour`.

2. **Wrote `stage.sh`** (owner-run, not CI-automated):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   ACTIVE=$(cat /etc/app/.active-colour)          # blue or green
   INACTIVE=$( [ "$ACTIVE" = blue ] && echo green || echo blue )
   INACTIVE_PORT=$( [ "$INACTIVE" = blue ] && echo 9101 || echo 9103 )

   # Deploy to inactive slot
   rsync -a --delete /var/www/app/releases/<NEW_SHA>/ /var/www/app/colours/$INACTIVE/
   systemctl restart api-$INACTIVE.service

   # Health-check loop (30 s budget)
   for i in $(seq 1 30); do
     curl -sf http://127.0.0.1:$INACTIVE_PORT/health -o /dev/null && break || sleep 1
   done
   curl -sf http://127.0.0.1:$INACTIVE_PORT/health -o /dev/null || \
     { echo "Inactive slot never healthy — aborting"; exit 1; }
   ```

3. **Wrote `promote.sh`** (owner-run after manual smoke check):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   ACTIVE=$(cat /etc/app/.active-colour)
   NEW=$( [ "$ACTIVE" = blue ] && echo green || echo blue )
   NEW_PORT=$( [ "$NEW" = blue ] && echo 9101 || echo 9103 )

   # Atomic Nginx swap — zero-downtime
   sed -i "s/app-$ACTIVE/app-$NEW/g" /etc/nginx/conf.d/app.conf
   nginx -t && systemctl reload nginx

   echo "$NEW" > /etc/app/.active-colour
   echo "Promoted $NEW (port $NEW_PORT). Old colour $ACTIVE still warm for 5 min rollback."
   ```

4. **Rollback**: if the new colour regresses, re-run `promote.sh` — it swaps back in < 1 s (`nginx reload` is atomic). Old colour stays warm for 5 minutes before being recycled.

5. **CI gate**: GitHub Actions builds, runs unit tests, runs Playwright on port 9190 (isolated CI slot), and only reports green if all pass. `promote.sh` is never run by CI.

## Evidence

- Deploy frequency: from ~2/week (weekend-avoidance) to 8–10/week after failover script adoption.
- Measured promotion downtime: 0 dropped connections (verified with `wrk -t4 -c50 -d15s` running during `nginx reload`).
- Rollback drill: 3 practice rollbacks, all < 2 s end-to-end.

## Result

Zero-downtime deploys with a fast, manual promote step. Rollback time reduced from 8 min (re-deploy old build) to < 2 s (re-run `promote.sh`). Weekend deploys are now routine.

---
*Names, IPs, domains, and tokens are placeholders.*
