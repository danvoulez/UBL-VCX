# Operating Model (Thin Shell)

This repository does not vendor UBL source code.

- Runtime binary comes from `UBL-CORE` (`contracts/VERSIONS.lock`).
- This repo owns only config, process lifecycle (PM2), deployment scripts, and validation.

## Update Flow

1. Change `CORE_REF` in `contracts/VERSIONS.lock`.
2. Run `make install-binary`.
3. Run `make restart` and `make smoke`.
4. If healthy, `make save` to persist PM2 process list.

## Rollback Flow

1. Revert lock file refs.
2. Run `make install-binary`.
3. Run `make restart` and `make smoke`.
