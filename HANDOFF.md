# Handoff: TP CI/CD EPSI (repo callmezik0/Project_CI_CD)

Paste this whole file as the first message of the new session.

## Context
The repo holds a school lab exercise (EPSI B4 Infra, "TP CI/CD"). It covers the full chain:
Flask app → pytest → Docker image → GHCR (by digest) → deploy to a preprod VM over SSH → rollback.
It is all written in French. The repo is **private** and its default branch is `main`.

- App: `app.py`, the NovaServices ticket API with `/health`, `/version` (version + commit), and `/tickets` (V2 adds `?status=`). `VERSION` = 2.0.0.
- Tests: `tests/test_app.py` (7 tests).
- `.github/workflows/ci-cd.yml`: jobs `Tests (pytest)` → `Image Docker` (build + smoke test; pushes to GHCR only on main)
  → `Déploiement préproduction` (skipped until the repo variable `DEPLOY_HOST` exists) and `Retour arrière manuel` (workflow_dispatch `action=rollback`).
  workflow_dispatch also has `simulate_failure` (makes /health return 503) for step 13.
- `deploy.sh` runs ON the VM: it pulls `image@digest`, checks /health and /version against the expected commit, and rolls back to the previous digest automatically on failure (the job still exits 1).
- `scripts/protect-main.sh`, `scripts/setup-github.sh` (VM vars at **repo** level, SSH key + known_hosts as secrets of the `preprod` environment), `scripts/wait-for-http.sh`.
- Docs: `README.md` (step-by-step guide), `docs/FICHE_CHOIX.md`, `docs/PREUVES.md` (evidence checklist + incident write-up), `docs/repetition/` (local rehearsal logs).

## State as of 2026-11-03
| Item | State |
|---|---|
| PR #1 `feature/version-api` | merged, CI green |
| PR #2 `feature/v2-filtre-statut` | merged **while its head was red** (deliberate regression, run #4). `main` has been broken since (run #5 failed at Tests; nothing was published or deployed) |
| PR #3 `fix/regression-tickets` | **open**, CI green (run #6). Reverts the regression and documents the incident in `docs/PREUVES.md` |
| Protection of `main` | **not set** |
| GHCR image | 1.0.0 published by run #2; V2 not published yet |
| VM (step 11) | not configured; the deploy job is skipped |

Step 8 evidence already exists: red = run #4 (PR #2), green = run #6 (PR #3).

## To do, in order
1. Protect `main` (user does this in the browser if the session proxy blocks admin API writes): required checks
   `Tests (pytest)` + `Image Docker`, branches up to date, PR required (0 approvals if solo), no bypass.
   Note: a private repo on a free plan doesn't enforce protection rules; the user may make the repo public.
2. Merge PR #3, then check the `main` run: Tests + Image Docker green, digest in the run summary, package visible in GHCR.
3. Step 11: once the user has the VM details (IP, user, app port, private key, instructor's SSH fingerprint), run
   `scripts/setup-github.sh callmezik0/Project_CI_CD <IP> <user> <port> <key>`, then re-run the workflow on main → deploy job runs.
4. Step 13: V2 is already on main. Run workflow_dispatch with `simulate_failure=true` (expected: job red, logs with 503, automatic rollback),
   then `action=rollback` (back to the previous digest). Verify `/version` on the VM after each.
5. Tick off `docs/PREUVES.md`. Do NOT reuse merged branches; open a new branch + PR for any change.

## Notes
- Never commit the GitHub token or the SSH key. A previous token was pasted in chat; the user should have revoked it.
- Docker Hub may rate-limit pulls in the sandbox: `mirror.gcr.io/library/python:3.12-slim` works. Local `pip` inside `docker build` needs the proxy CA (only matters for local tests, not for the real CI).
