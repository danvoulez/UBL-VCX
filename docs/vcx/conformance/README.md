# VCX Conformance Suite

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Purpose

Define the public conformance structure for VCX implementations.

This suite is the execution artifact behind readiness gates:

- S0-G3 (negative validation coverage)
- S1-G2 (conformance suite v1)

## Suite Layout

```text
docs/vcx/conformance/
  README.md
  vectors/
    v1/
      positive/
      negative/
```

## Vector Types

- Positive vectors: valid inputs and expected verification outputs.
- Negative vectors: controlled corruptions and expected verifier errors.

## Vector Metadata Contract

Each vector file SHOULD include:

- `id`: stable vector id
- `version`: vector schema version
- `profile`: applicable VCX profile
- `inputs`: manifest/payload references
- `operation`: build/verify mode
- `expected`: expected result (pass/fail + error or root/cids)

## Initial v1 Seed

Current initial vectors are under:

- `docs/vcx/conformance/vectors/v1/positive/`
- `docs/vcx/conformance/vectors/v1/negative/`

Current seed count:

- 20 positive vectors
- 20 negative vectors

These vectors will continue to expand as IC0 and manifest specs are frozen.

## Reference Runner (current)

Reference implementation commands:

```bash
cd vcx-pack
cargo run -p vcx_pack_cli -- build --manifest examples/manifest.vcx.json --payload application/vcx-ic0t=examples/payloads/tile0.ic0t --out out.vcx --strict-unc1
cargo run -p vcx_pack_cli -- verify --input out.vcx --full
```

Automated conformance runner:

```bash
scripts/vcx_conformance.sh --report-file docs/vcx/conformance/reports/latest.json
```

The runner currently executes:

- positive vector: `basic_pack.vector.json`
- all negative vectors found in `docs/vcx/conformance/vectors/v1/negative/*.json`

Committed run evidence is recorded under:

- `docs/vcx/conformance/reports/`
- `docs/vcx/conformance/COVERAGE_MAP.md`

## Exit-to-v1 Criteria

Conformance suite v1 is considered complete when:

1. At least 20 positive vectors and 20 negative vectors are published.
2. Every normative validation path in `vcx_pack` has at least one negative vector.
3. Expected outputs are stable and version-pinned.
