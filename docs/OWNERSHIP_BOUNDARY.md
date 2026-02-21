# Ownership Boundary

`UBL-VCX` is intentionally a thin operational shell.

## This Repo Owns

1. Local runtime configuration (`config/project.env`).
2. Process lifecycle (`pm2/ecosystem.config.cjs` and Make targets).
3. Upstream version locks (`contracts/VERSIONS.lock`).
4. Local smoke checks and deployment scripts.

## This Repo Does Not Own

1. Core behavior, trust model, pipeline semantics (`UBL-CORE`).
2. Upstream API/protocol decisions.

## Governance Rule

- If behavior must change, open upstream issue/PR first.
- Keep this repo limited to configuration, rollout, and operations.
