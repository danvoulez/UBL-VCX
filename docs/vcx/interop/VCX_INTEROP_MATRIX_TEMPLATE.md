# VCX Interoperability Matrix Template

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Purpose

Provide a standard matrix format for cross-implementation interoperability evidence.

## Matrix

| Producer Impl | Consumer Impl | Artifact | Build | Verify | Full Verify | Result | Notes |
|---|---|---|---|---|---|---|---|
| ref-rust | ref-rust | vcx-pack/v1 | pass | pass | pass | pass | baseline |
| ref-rust | impl-B | vcx-pack/v1 | pass | pass | pending | pending | fill during S2 |
| impl-B | ref-rust | vcx-pack/v1 | pending | pending | pending | pending | fill during S2 |

## Required Coverage

- At least 2 independent producer implementations.
- At least 2 independent consumer/verifier implementations.
- Positive and negative conformance vectors executed by all pairs.
