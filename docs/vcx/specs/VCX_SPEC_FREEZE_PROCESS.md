# VCX Specification Freeze Process (v1)

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Purpose

Define how VCX normative specs enter and exit a candidate freeze window.

## Freeze Scope

Freeze applies to:

- `docs/vcx/specs/VCX_IC0_SPEC.md`
- `docs/vcx/specs/VCX_PACK_SPEC.md`
- `docs/vcx/specs/VCX_MANIFEST_SPEC.md`
- `docs/vcx/specs/VCX_SIDECAR_SPEC.md`
- `docs/vcx/specs/VCX_COMPATIBILITY_POLICY.md`
- `docs/vcx/specs/VCX_SECURITY_MODEL.md`

## Candidate Window (current cycle)

- Start: **2026-03-15**
- End: **2026-04-15**
- Target: VCX Candidate (`S1`) readiness review

## Rules During Freeze

- No breaking normative changes allowed.
- Clarifications are allowed only if they do not alter wire/semantic behavior.
- Any requested breaking change must be deferred to next freeze cycle.

## Entry Criteria

Before freeze start:

1. Conformance seed suite published.
2. Compatibility policy published.
3. Security model published.
4. Status board updated with evidence links.

## Exit Criteria

At freeze end:

1. No unresolved blocker issues on normative docs.
2. Conformance vectors execute cleanly on reference implementation.
3. Review sign-off recorded by Core Runtime + Security.

## Change Exception Process

Exception requests during freeze MUST include:

1. Risk statement.
2. Compatibility impact.
3. Migration note.
4. Explicit approval from Core Runtime owner.
