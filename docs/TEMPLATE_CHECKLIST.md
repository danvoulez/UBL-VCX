# Template Checklist (New Project Bootstrap)

Use this checklist every time you create a new personal/project repo from `UBL-SHELLS` or `UBL-VCX`.

## 1) Create New Repository

1. Create a new empty GitHub repository (example: `UBL-PROJECT-ACME`).
2. Copy this template repository to a local folder with the new project name.
3. Point `origin` to the new repository URL.

Example:

```bash
cp -R /path/to/UBL-SHELLS /path/to/UBL-PROJECT-ACME
cd /path/to/UBL-PROJECT-ACME
git remote remove origin
git remote add origin https://github.com/<owner>/UBL-PROJECT-ACME.git
```

## 2) Identity and Runtime Basics

1. Update `README.md` project name and purpose.
2. Update PM2 app name in `pm2/ecosystem.config.cjs`:
   - `name: "ubl-gate"` -> `name: "ubl-gate-acme"` (or your project name).
3. Copy env file:

```bash
cp config/project.env.sample config/project.env
```

4. Set project port/address in `config/project.env`:
   - `UBL_GATE_BIND=127.0.0.1:4XXX`
5. Keep safety defaults enabled:
   - `REQUIRE_UNC1_NUMERIC=true`
   - `F64_IMPORT_MODE=reject`

## 3) Pin Upstream Refs

1. Edit `contracts/VERSIONS.lock`.
2. Prefer release tags for production:
   - `CORE_REF=vX.Y.Z`
3. Optional: if you have a release binary URL, set `CORE_BINARY_URL`.

## 4) Install and Boot Process

1. Install binary:

```bash
make install-binary
```

2. Start process with PM2:

```bash
make bootstrap
```

3. Validate contract path:

```bash
make smoke
```

4. Persist PM2 process list:

```bash
make save
```

## 5) Operational Validation

1. `make status` must show process online.
2. `make logs` must show no crash loop.
3. `GET /healthz` must return OK.
4. One smoke chip must return a receipt/output cid.

## 6) Upgrade Procedure (Day-2)

1. Update ref:
   - `make update-core REF=vX.Y.Z`
2. Reinstall and restart:
   - `make install-binary`
   - `make restart`
3. Validate:
   - `make smoke`
4. Persist:
   - `make save`

## 7) Rollback Procedure

1. Revert `contracts/VERSIONS.lock` to known-good refs.
2. Run:
   - `make install-binary`
   - `make restart`
   - `make smoke`
   - `make save`

## 8) Governance Boundary

1. Do not patch runtime behavior in this repo.
2. Behavioral changes must be requested upstream (`UBL-CORE`).
3. This repo should only own:
   - config,
   - process lifecycle,
   - lock refs,
   - operational scripts/checks.

## 9) Final Pre-Go-Live Checklist

1. Repository private/public mode confirmed.
2. `config/project.env` backed up securely.
3. PM2 startup configured (`pm2 startup` run once).
4. Known-good lock refs documented in release notes.
5. First rollback drill executed successfully.
