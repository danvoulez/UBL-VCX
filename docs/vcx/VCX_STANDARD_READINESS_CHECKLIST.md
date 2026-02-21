# VCX Standard Readiness Checklist v1

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Purpose

Define objective go/no-go gates to move VCX from internal protocol work to a publishable, verifiable, and governable open standard.

## Scope

This checklist covers:

- VCX-Core (codec + graph model)
- VCX-PACK (container/on-wire)
- VCX sidecars and editing protocol profiles
- Conformance, security, governance, and adoption readiness

## Stage Model

| Stage | Meaning | Exit Rule |
|---|---|---|
| S0 Draft | Internal design and reference implementation | All S0 gates pass |
| S1 Candidate | Frozen candidate for external implementers | All S1 gates pass |
| S2 Proposed Standard | Multi-implementation interoperability demonstrated | All S2 gates pass |
| S3 Standard 1.0 | Stable release with governance and compliance process | All S3 gates pass |

## S0 Draft Gates

| ID | Gate | Pass Criteria |
|---|---|---|
| S0-G1 | Normative documents split from narrative docs | Dedicated normative specs exist for bitstream, pack, manifest, and sidecars |
| S0-G2 | Reference implementation reproducibility | Same inputs produce same outputs/CIDs across repeated runs (CI verified) |
| S0-G3 | Negative validation coverage | Corruptions are rejected for header/index/payload/trailer paths |
| S0-G4 | Canon constraints | UNC-1 and envelope anchor constraints enforced in tooling |
| S0-G5 | Public examples | Minimal examples available for build, verify, ingest, and extract |

## S1 Candidate Gates

| ID | Gate | Pass Criteria |
|---|---|---|
| S1-G1 | Spec freeze window | Normative docs frozen for a dated review window (no breaking changes) |
| S1-G2 | Conformance suite v1 | KAT + negative vectors published with deterministic expected outputs |
| S1-G3 | Compatibility policy | Versioning, extension, and deprecation policy published |
| S1-G4 | Security review | Threat model + security checklist published and reviewed |
| S1-G5 | MIME/media registration plan | Clear media type and registration path documented |

## S2 Proposed Standard Gates

| ID | Gate | Pass Criteria |
|---|---|---|
| S2-G1 | Independent implementations | At least 2 independent implementations pass conformance |
| S2-G2 | Interop matrix | Cross-implementation pack encode/decode/verify matrix published |
| S2-G3 | Performance baseline | Reproducible benchmark profile published (CPU, latency, size) |
| S2-G4 | Governance process active | Working group, decision process, and change control operating |
| S2-G5 | Legal/IPR posture | Public licensing and patent posture statement published |

## S3 Standard 1.0 Gates

| ID | Gate | Pass Criteria |
|---|---|---|
| S3-G1 | Final specification bundle | Versioned spec bundle (1.0) with immutable release artifacts |
| S3-G2 | Certification workflow | Conformance test and result publication workflow operational |
| S3-G3 | Change management | Stable errata and revision process with compatibility guarantees |
| S3-G4 | Production proof | At least 2 production pilots with published metrics and incident learnings |
| S3-G5 | Ecosystem tooling | Validator CLI + SDK coverage sufficient for third-party onboarding |

## Required Deliverables by Domain

| Domain | Minimum Deliverable |
|---|---|
| Normative Spec | `VCX-IC0`, `VCX-PACK`, manifest schema, sidecar schemas |
| Conformance | Test vectors, expected CIDs/hashes, negative corruption set |
| Security | Threat model, key/signature profile, verification guidance |
| Governance | Membership/process doc, release policy, breaking-change policy |
| Interop | Independent implementations and public interop report |
| Adoption | Migration guide from legacy formats and compatibility profile |

## Release Decision Rule

Promotion to the next stage requires:

1. All gates for current stage marked `PASS`.
2. No open `BLOCKER` findings in conformance or security.
3. Evidence artifacts linked in the checklist tracking issue/board.

## Current Execution Note

Use this checklist as the canonical readiness rubric for VCX standardization work. Strategy or roadmap documents should reference this file instead of redefining stage criteria.

Execution status tracking lives in:
`docs/vcx/VCX_STANDARD_STATUS.md`.
