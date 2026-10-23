# devops-case-studies

[![CI](https://github.com/NoorSiddiquiDubai/devops-case-studies/actions/workflows/ci.yml/badge.svg)](https://github.com/NoorSiddiquiDubai/devops-case-studies/actions/workflows/ci.yml)

Five sanitized DevOps case studies — each structured as **Problem → Action → Evidence → Result**. Scripts and config snippets use placeholder values; no real IPs, domains, or credentials are included.

## Case Studies

| # | Title |
|---|-------|
| 01 | [Self-Hosted CI Runner + Playwright Gate](case-studies/01-self-hosted-ci-playwright.md) |
| 02 | [Blue/Green Auto-Failover](case-studies/02-blue-green-auto-failover.md) |
| 03 | [Rescue-Mode RAID 6 Lockout Recovery (sshd StrictModes)](case-studies/03-raid6-rescue-mode.md) |
| 04 | [cPanel → AWS EC2 + Caddy Cutover](case-studies/04-cpanel-to-ec2-caddy.md) |
| 05 | [Secret-Scanning Sweep](case-studies/05-secret-scanning-sweep.md) |

## Scripts

Reusable helper scripts (placeholders marked `<LIKE_THIS>`):

| Script | Purpose |
|--------|---------|
| [`health-check.sh`](scripts/health-check.sh) | Poll HTTP endpoint until 200 or timeout |
| [`blue-green-promote.sh`](scripts/blue-green-promote.sh) | Atomic Nginx upstream swap |
| [`gitleaks-scan.sh`](scripts/gitleaks-scan.sh) | Install gitleaks and scan for secrets |

## How to Run

### Locally

```bash
# Clone
git clone https://github.com/NoorSiddiquiDubai/devops-case-studies.git
cd devops-case-studies

# Validate scripts are syntax-clean
for f in scripts/*.sh; do bash -n "$f" && echo "OK: $f"; done

# Run gitleaks scan (requires gitleaks installed)
gitleaks detect --source . --redact --exit-code 1
```

### CI (GitHub Actions)

Every push and pull request to `main` runs:
1. `gitleaks detect` — 0 findings required to pass
2. Verify all 5 case study files are present
3. Check no private IP addresses appear in case study text
4. `bash -n` syntax validation on all scripts

## License

MIT — see [LICENSE](LICENSE).
