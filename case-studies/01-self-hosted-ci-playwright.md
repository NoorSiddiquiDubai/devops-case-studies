# Case Study 01 — Self-Hosted CI Runner + Playwright Gate

## Problem

A SaaS product deployed via GitHub Actions was using GitHub-hosted runners. End-to-end UI tests (Playwright, Chromium) needed access to a staging environment only reachable on a private subnet — GitHub-hosted runners have no network path to internal services. CI routinely passed unit tests but missed regressions caught only by UI tests.

## Action

1. **Provisioned a dedicated runner VM** on the private subnet (Ubuntu 22.04 LTS, 4 vCPU, 8 GB RAM) with outbound HTTPS to `github.com` only.
2. **Registered the runner** as a self-hosted runner under the repo org with label `staging`:
   ```bash
   # On runner VM — download and configure
   mkdir -p ~/actions-runner && cd ~/actions-runner
   curl -sL https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz | tar xz
   ./config.sh --url https://github.com/<ORG>/<REPO> \
               --token <RUNNER_REGISTRATION_TOKEN> \
               --labels staging,playwright
   sudo ./svc.sh install && sudo ./svc.sh start
   ```
3. **Installed Playwright system deps** once on the runner VM:
   ```bash
   npx playwright install-deps chromium
   ```
4. **Scoped workflow** to self-hosted runner only for the Playwright job, keeping the build/lint job on hosted runners:
   ```yaml
   playwright-e2e:
     runs-on: [self-hosted, staging, playwright]
     needs: [build]
   ```
5. **Isolation fence**: each CI run starts a fresh app instance on a dedicated ephemeral port (`9190 + $GITHUB_RUN_NUMBER % 100`), tears it down in an `if: always()` step, and asserts no writes occurred outside `$GITHUB_WORKSPACE` and `/tmp`.

## Evidence

- Before: 3 regressions merged to main over 8 weeks because UI tests were skipped.
- After: Playwright gate added on 2026-08-01; 0 regressions in subsequent 8 weeks.
- Mean CI wall time: 7 min 40 s (build + lint on hosted) + 4 min 10 s (Playwright on self-hosted, parallel).
- Runner uptime: 99.7 % over first 30 days (systemd watchdog unit, auto-restart on failure).

## Result

All PRs targeting `main` must pass the Playwright gate. Regressions are caught before merge. The self-hosted runner costs ~$18/month vs ~$80/month estimated for equivalent GitHub-hosted minutes.

---
*Names, IPs, domains, and tokens are placeholders.*
