# UBL-VCX

Official VCX thin-shell repository for running UBL in product context without vendoring source code.

- No copy of `UBL-CORE` code.
- Pulls runtime binary from `UBL-CORE` ref in `contracts/VERSIONS.lock`.
- Runs as local PM2-managed process.

## Quick Start

```bash
cp config/project.env.sample config/project.env
make bootstrap
make smoke
```

## Upgrade

```bash
make update-core REF=v0.1.0-core-baseline
make install-binary
make restart
make smoke
make save
```

## Files

- `contracts/VERSIONS.lock`: upstream refs and binary source.
- `config/project.env.sample`: local runtime config.
- `pm2/ecosystem.config.cjs`: PM2 process definition.
- `scripts/`: install/start/smoke/update helpers.

## Documentation

- `docs/OPERATING_MODEL.md`
- `docs/PM2_SETUP.md`
- `docs/UPGRADE_ROLLBACK.md`
- `docs/OWNERSHIP_BOUNDARY.md`
- `docs/TEMPLATE_CHECKLIST.md` (bootstrap reference)
