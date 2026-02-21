# VCX-IC0 Bitstream Specification (v0.1)

**Status**: draft
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Scope

Define the deterministic intra profile for VCX video payload chunks (`application/vcx-ic0t`).

## Normative Goals

- Same input frame + same profile + same implementation version MUST produce identical chunk bytes.
- Encoder MUST NOT depend on nondeterministic factors (random seeds, thread race ordering, wall clock).

## Tile Model

- Tile size: `64x64` pixels.
- Tile payload is content-addressed and stored as a chunk in VCX-PACK payload region.
- Tile CID is computed from raw payload bytes using VCX CID rule:
  `CID = BLAKE3(NRF(Bytes(payload_raw)))`.

## Determinism Requirements

- Processing order MUST be deterministic (lexicographic tile order).
- Quantization tables MUST be profile-pinned and versioned.
- Entropy coding tables MUST be profile-pinned and versioned.
- Any field affecting bitstream output MUST be explicitly versioned and included in profile definition.

## Conformance Notes

This document defines deterministic constraints and chunk contract only.
Detailed transform and coding tables are tracked as follow-up standardization items before S1 candidate freeze.
