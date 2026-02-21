# Upgrade and Rollback

This repository upgrades by changing lock refs, then reinstalling the runtime binary.

## Upgrade Flow

1. Update lock:
   - `make update-core REF=vX.Y.Z`
2. Reinstall binary:
   - `make install-binary`
3. Restart process:
   - `make restart`
4. Validate:
   - `make smoke`
5. Persist PM2 state:
   - `make save`

## Rollback Flow

1. Revert `contracts/VERSIONS.lock` to previous refs.
2. Run:
   - `make install-binary`
   - `make restart`
   - `make smoke`
3. Persist:
   - `make save`

## Notes

- Prefer release tags over `main` in production.
- Keep one known-good lock snapshot per environment.
