# VCX MIME and Media Registration Plan (v1)

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Purpose

Define the media-type registration path for VCX artifacts and profile names used by implementations.

## Current Types in Use

- `application/vcx-pack`
- `application/vcx-ic0t`
- `application/vcx-sidecar`

## Registration Strategy

1. Use vendor-prefixed provisional names during pre-standard phase.
2. Prepare IANA registration package when S1 criteria are met.
3. Promote to final names after S2 interoperability evidence.

## Provisional Mapping (Pre-Registration)

| Artifact | Provisional Type | Notes |
|---|---|---|
| Pack file | `application/vcx-pack` | Binary container (`VCX1`) |
| IC0 tile payload | `application/vcx-ic0t` | Deterministic tile payload |
| Sidecar chips payload | `application/vcx-sidecar` | Predictability/edit sidecar payloads |

## Registration Package Checklist

- Stable specification references
- Security considerations section
- Interoperability considerations section
- Encoding considerations (binary/json)
- File extension and magic bytes
- Contact and change controller information

## Acceptance Gate

This plan is considered complete for S1-G5 when:

1. registration package draft is linked in repository;
2. media type definitions are stable in specs;
3. compatibility and security documents reference these media types.
