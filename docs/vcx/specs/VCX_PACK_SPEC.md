# VCX-PACK Container Specification (v1)

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Scope

Define the binary container and verification rules for VCX-PACK v1.

## File Layout

```
[Header 96B] [Manifest NRF bytes] [Index bytes] [PayloadRegion] [MerkleTrailer]
```

All numeric fields are little-endian.

## Header

- magic: `VCX1`
- version: `1`
- header_len: `96`
- flags: bit 1 (`0b0010`) indicates Merkle trailer present
- offsets/lengths for: manifest, index, payload region, trailer

Normative constraints:

- `manifest_off` MUST be `96`.
- `index_off`, `payload_off`, `trailer_off` MUST be 8-byte aligned.
- regions MUST NOT overlap.
- all regions MUST fit within file bounds.

## Manifest Region

- Raw NRF bytes of a manifest object.
- Manifest MUST decode as NRF map and include envelope anchors:
  `@type`, `@id`, `@ver`, `@world` as strings.

## Index Region

- magic: `VIDX`
- version: `1`
- entry_len: `96`
- reserved header field MUST be zero
- entries sorted strictly by `cid[32]` (no duplicates)

Per-entry fields:

- `cid_algo=1`, `cid_len=32`
- `cid[32]`
- `mime_tag`
- `flags`
- `payload_off`, `payload_len`
- `payload_hash = BLAKE3(payload_raw)`
- entry padding MUST be zero

## Payload Region

- Concatenation of raw payload blobs.
- Each blob MUST be reachable via index offsets.
- Blob boundaries MUST remain inside payload region.
- Blob offsets MUST be 8-byte aligned.

## Merkle Trailer

- magic: `VMRK`
- version: `1`
- flags MUST be zero
- hash algo `1` (BLAKE3)
- reserved bytes MUST be zero
- includes root and full level list

Leaf commitments:

- leaf 0: manifest hash + manifest length
- leaf 1: index hash + index length
- leaf 2..N: payload hash + payload CID + payload length

Verifier MUST reject invalid Merkle tree shape and root mismatch.

## Strict Verification Levels

- Normal verify: validates structure, ordering, Merkle root from index metadata.
- Full verify: additionally recomputes `payload_hash` and payload `CID` from bytes.

## Reference Implementation

- Builder/verifier crate: `vcx-pack/crates/vcx_pack`
- CLI: `vcx-pack/tools/vcx_pack_cli`
