# Case Study 05 — Secret-Scanning Sweep

## Problem

A 3-year-old monorepo had accumulated secrets committed directly to git over time: API keys hardcoded in test scripts, database passwords in CI config comments, and a `.env.example` that contained real values (copied from production). GitHub's push protection was not enabled. A routine audit found 14 unique credential patterns across 47 commits in the git history.

## Action

### Step 1 — Baseline scan with gitleaks

```bash
# Install gitleaks
curl -sL https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/\
gitleaks_8.21.2_linux_x64.tar.gz | tar xz -C /usr/local/bin

# Full history scan
gitleaks detect --source . --report-format json \
  --report-path /tmp/gitleaks-report.json

# Count findings
jq length /tmp/gitleaks-report.json
# 14
```

### Step 2 — Rotate all found credentials

For each finding (`jq '.[].Description' /tmp/gitleaks-report.json`):

| Type | Action |
|------|--------|
| AWS access key | Deactivated in IAM console; new key issued with least-privilege policy |
| Stripe test key | Rotated in Stripe dashboard |
| SendGrid API key | Revoked; new key scoped to transactional send only |
| MongoDB URI (including password) | Changed DB password; URI updated in secrets manager |
| Generic `password=` in test file | Replaced with env var reference |

### Step 3 — Remove secrets from git history with git-filter-repo

```bash
pip install git-filter-repo

# Build a replacements file (one pattern per line: <literal>==><REPLACEMENT>)
# Replace <YOUR_ACTUAL_KEY_HERE> with the real leaked value from gitleaks output
cat > /tmp/replacements.txt <<'EOF'
<YOUR_AWS_KEY_ID>==><AWS_KEY_REDACTED>
<YOUR_STRIPE_TEST_KEY>==><STRIPE_KEY_REDACTED>
<YOUR_SENDGRID_KEY>==><SENDGRID_KEY_REDACTED>
mongodb+srv://user:<YOUR_DB_PASS>@cluster.example.mongodb.net==>mongodb+srv://user:REDACTED@cluster.example.mongodb.net
EOF

git filter-repo --replace-text /tmp/replacements.txt --force
```

Force-pushed rewritten history to all branches (coordinated with team — 2-day freeze window).

### Step 4 — Block future leaks

1. **GitHub push protection** enabled at org level (blocks pushes containing known secret patterns).
2. **Pre-commit hook** via gitleaks:
   ```bash
   # .git/hooks/pre-commit (or install via pre-commit framework)
   gitleaks protect --staged --redact || exit 1
   ```
3. **`.gitignore`** hardened — added explicit patterns for `.env`, `.env.*`, `*.key`, `*.pem`, `*.p12`.
4. **`.env.example`** purged and replaced with placeholder values only (`DB_PASS=your_password_here`).
5. **GitHub Actions secret scanning** alert emails routed to security@ distribution list.

### Step 5 — Verify clean state

```bash
gitleaks detect --source . --report-format json --report-path /tmp/post-clean.json
jq length /tmp/post-clean.json
# 0
```

## Evidence

- Pre-sweep: 14 findings across 47 commits, spanning 3 years of history.
- All 14 credentials rotated within 4 hours of discovery.
- Post-rewrite scan: 0 findings.
- No credentials were found in external breach databases (checked via HIBP API for email-linked keys).
- Pre-commit hook verified: staging a file containing a real-looking AWS key ID pattern → gitleaks blocks the commit and prints the finding.

## Result

Full git history cleaned, all credentials rotated, and three complementary controls (push protection, pre-commit hook, `.gitignore`) prevent recurrence. Secret-scanning sweep is now part of the quarterly security checklist.

---
*All credential patterns shown are placeholders or publicly-documented test values (e.g., AWS example key from official docs).*
