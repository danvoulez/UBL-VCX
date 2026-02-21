# VCX Conformance Coverage Map (v1 Seed)

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Purpose

Map normative verifier failure paths to negative conformance vectors.

## Coverage

| Error / Check | Vector |
|---|---|
| `BadMagic` | `bad_magic.vector.json` |
| `BadHeaderLen(..)` | `bad_header_len.vector.json` |
| `NonZeroHeaderPadding` | `nonzero_header_padding.vector.json` |
| `MissingMerkleFlag` | `missing_merkle_flag.vector.json` |
| `UnexpectedManifestOffset(..)` | `unexpected_manifest_offset.vector.json` |
| `RegionOffsetNotAligned(index, ..)` | `misaligned_index_offset.vector.json` |
| `RegionOutOfBounds(payload)` | `region_out_of_bounds_payload.vector.json` |
| `RegionOverlap(manifest,index)` | `region_overlap_manifest_index.vector.json` |
| `BadIndexMagic` | `bad_index_magic.vector.json` |
| `NonZeroIndexReserved` | `nonzero_index_reserved.vector.json` |
| `UnsupportedCidAlgo(..)` | `unsupported_cid_algo.vector.json` |
| `BadCidLen(..)` | `bad_cid_len.vector.json` |
| `NonZeroIndexEntryPadding` | `nonzero_index_padding.vector.json` |
| `PayloadEntryOffsetNotAligned` | `payload_entry_offset_not_aligned.vector.json` |
| `PayloadEntryOutOfPayloadRegion` | `payload_entry_out_of_region.vector.json` |
| `PayloadHashMismatch` (`--full`) | `payload_hash_mismatch_full.vector.json` |
| `BadMerkleMagic` | `bad_merkle_magic.vector.json` |
| `UnsupportedMerkleFlags(..)` | `unsupported_merkle_flags.vector.json` |
| `NonZeroMerkleReserved` | `nonzero_merkle_reserved.vector.json` |
| `MerkleLeafCountMismatch` | `merkle_leaf_count_mismatch.vector.json` |

## Run Baseline

Seed baseline run (2026-02-20):

- positives: 20/20 pass
- negatives: 20/20 pass

Reference:

- `docs/vcx/conformance/reports/SEED_RUN_2026-02-20.md`
