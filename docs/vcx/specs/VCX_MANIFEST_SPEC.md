# VCX Manifest Specification (v1)

**Status**: draft
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Scope

Define the canonical manifest contract used by VCX-PACK and VCX sidecars.

## Envelope

Manifest MUST include:

- `@type`
- `@id`
- `@ver`
- `@world`

These anchors define chip identity and execution scope in UBL pipeline.

## Canon and Numeric Rules

- Manifest MUST be NRF-encodable.
- Canonical numeric fields SHOULD use UNC-1 objects.
- In strict build mode, JSON numeric literals are rejected.

## Core Fields (minimum profile)

- `@type`: typically `vcx/manifest`
- `@id`: manifest identifier
- `@ver`: manifest schema/profile version
- `@world`: UBL world scope
- `timebase`: rational UNC-1
- `duration_ticks`: integer UNC-1
- `video` descriptor (codec/profile/geometry)
- timeline/group list with tile references (`cid`, `mime`, `role`)

## Reference Integrity

- Every media reference MUST resolve to a payload blob by CID.
- CID MUST follow VCX payload CID rule.
- Any manifest rewrite MUST produce a new manifest identifier and audit trail entry.

## Versioning

- Breaking field semantic changes MUST bump major manifest profile version.
- Backward-compatible additive fields MAY use minor version bump.
