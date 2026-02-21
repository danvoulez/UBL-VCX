# VCX Compatibility and Versioning Policy (v1)

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Purpose

Define compatibility guarantees and versioning rules for VCX artifacts.

## Version Domains

VCX has independent version domains:

- `vcx-pack` container version
- manifest profile version (`@ver`)
- sidecar profile version (`@ver`)
- codec profile version (IC0 profile id/version)

## Compatibility Levels

- **Wire-compatible**: existing verifiers can parse and validate without behavior change.
- **Backward-compatible**: new producer outputs can be consumed by older consumers with equivalent semantics.
- **Breaking**: old consumers cannot safely parse or preserve semantics.

## SemVer Rules

- `MAJOR` bump for breaking wire or semantic changes.
- `MINOR` bump for additive, optional fields with preserved semantics.
- `PATCH` bump for clarifications or bug fixes without format/semantic changes.

## Pack Compatibility Rules

- `PACK_VERSION` major bump is required for binary layout changes.
- Reserved fields MUST remain zero until assigned by a new version.
- Verifiers MUST reject unknown mandatory flags.

## Manifest and Sidecar Compatibility Rules

- New mandatory fields require major bump.
- New optional fields require minor bump.
- Existing field meaning changes require major bump.

## Deprecation Policy

- Deprecated fields MUST be documented with replacement and sunset version.
- Support window for deprecated fields: minimum 2 minor releases after deprecation notice.

## Extension Policy

- Extensions MUST be explicitly namespaced and documented.
- Extensions MUST NOT change canonical hash/CID rules.
- Unknown extension fields MUST be ignored only when explicitly marked optional.

## Change Control

A change proposal MUST include:

1. Compatibility impact classification.
2. Migration notes.
3. Conformance vector updates.
4. Rollback strategy.
