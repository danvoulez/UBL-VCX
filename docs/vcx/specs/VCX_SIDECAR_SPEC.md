# VCX Sidecar and Editing Chips Specification (v1)

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Scope

Define normative chip types for predictability sidecars and verifiable editing decisions.

## Common Envelope

All sidecar and edit chips MUST include:

- `@type`
- `@id`
- `@ver`
- `@world`

## Realtime Predictability Chip

Type: `vcx/sidecar.predictability.realtime`

Required fields:

- `target_manifest`
- `group_seq`
- `window { groups, duration_ms }`
- `observed { guessed_tiles, correct_tiles, corrected_tiles }`
- `metrics { instant_hit_rate, ewma_hit_rate, ewma_volatility, predictability_score, samples, mode }`
- `policy_hint { mode, max_speculative_tiles_per_group, prefetch_depth_groups }`

Normative checks:

- `correct_tiles <= guessed_tiles`
- `predictability_score` in `[0,1]`
- window values MUST be positive

## VOD Predictability Chip

Type: `vcx/sidecar.predictability.vod`

Required fields:

- `target_manifest`
- `global_stats { volatility_score, average_shot_length_ms }`
- `regions[]` with tile ranges, strategy, confidence

Normative checks:

- `volatility_score` and `confidence` in `[0,1]`
- `tile_range_start <= tile_range_end`

## Edit Decision Chip

Type: `vcx/edit.decision`

Required fields:

- `input_manifest`
- `output_manifest`
- `operations[]`
- `reencode_required`
- `editorial_receipt_cid`

Supported operations:

- `trim`
- `splice_insert`
- `swap_track_ref`
- `overlay_ref`

Normative checks:

- `operations` MUST be non-empty
- trim and overlay ranges MUST be valid (`start < end`)

## Predictability Algorithm Profile

Default profile parameters:

- `alpha = 0.25`
- `min_samples = 4`
- `high_threshold = 0.85`
- `low_threshold = 0.60`

Mode mapping:

- score `>= 0.85` -> `aggressive_ghost`
- score `< 0.60` -> `download_first`
- otherwise -> `balanced`

## Reference Implementation

- Protocol types and validation:
  `vcx-pack/crates/vcx_pack/src/streaming_protocol.rs`
- Predictor:
  `vcx-pack/crates/vcx_pack/src/realtime_predictability.rs`
