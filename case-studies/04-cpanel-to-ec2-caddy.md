# Case Study 04 — cPanel → AWS EC2 + Caddy Cutover

## Problem

A WordPress + Node.js API stack ran on shared cPanel hosting. Pain points:
- cPanel MySQL 5.7 (EOL); upstream required 8.0 for JSON column support.
- Shared hosting throttled Node.js to 1 vCPU / 512 MB — API responses p95 > 4 s.
- SSL renewal was manual (cPanel AutoSSL failed for wildcard domains).
- No staging environment; every deploy was directly to production.

## Action

### Infrastructure (AWS)

| Component | Before | After |
|-----------|--------|-------|
| Compute | Shared cPanel | EC2 t3.medium (2 vCPU, 4 GB) |
| Database | cPanel MySQL 5.7 | RDS MySQL 8.0 (db.t3.micro, Multi-AZ) |
| Web server | Apache (cPanel) | Caddy 2 (automatic HTTPS, HTTP/2) |
| DNS | cPanel nameservers | Route 53 (A → EC2 EIP) |
| SSL | Manual / AutoSSL | Caddy ACME (auto-renew) |

### Migration steps

1. **Provision EC2** with Ubuntu 22.04, install Caddy, Node.js 20 LTS, deploy app via GitHub Actions to `/var/www/app`.

2. **Caddy config** (`/etc/caddy/Caddyfile`):
   ```
   example.com, www.example.com {
     root * /var/www/app/public
     file_server
     reverse_proxy /api/* localhost:3000
     encode gzip
     header Strict-Transport-Security "max-age=31536000; includeSubDomains"
   }
   ```

3. **Database migration**:
   ```bash
   # Export from cPanel MySQL 5.7
   mysqldump -u <DB_USER> -p<DB_PASS> --single-transaction <DB_NAME> \
     | gzip > /tmp/db-export-$(date +%Y%m%d).sql.gz

   # Import to RDS 8.0
   zcat /tmp/db-export-*.sql.gz | mysql -h <RDS_ENDPOINT> -u admin -p <DB_NAME>
   ```

4. **DNS cutover** (low-TTL window):
   - Lowered TTL to 60 s 48 h before cutover.
   - Verified app fully functional on EC2 via `/etc/hosts` override.
   - Updated Route 53 A record to EC2 Elastic IP.
   - Monitored for 30 min; old cPanel left live for 24 h as fallback.

5. **Rollback plan**: cPanel stayed up with unchanged DNS TTL (60 s); rollback = revert Route 53 A record.

### Post-cutover hardening

- `ufw` rules: allow 22/tcp (restrict to bastion IP), 80/tcp, 443/tcp; deny all else.
- Unattended-upgrades enabled for security packages.
- EC2 instance profile with least-privilege IAM role (S3 read for uploads bucket only).
- RDS automatic backups: 7-day retention, 02:00 UTC maintenance window.

## Evidence

- API p95 response time: 4.1 s → 310 ms (10× improvement, same query load).
- SSL renewal: 0 manual interventions in first 90 days (Caddy ACME auto-renewed at 30 days remaining).
- cPanel decommissioned 14 days post-cutover with 0 support tickets for SSL or performance.

## Result

Stack runs on fully controlled infrastructure, MySQL 8.0 unblocks JSON column roadmap items, and Caddy handles SSL renewals automatically. Monthly cost: ~$55 (EC2 + RDS reserved 1-yr) vs $120 (cPanel Business plan).

---
*Names, IPs, domains, RDS endpoints, and credentials are placeholders.*
