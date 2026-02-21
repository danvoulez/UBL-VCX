# VCX Security Model (v1)

**Status**: active
**Owner**: Core Runtime + Security
**Last reviewed**: 2026-02-20

## Purpose

Define the security model for VCX artifacts and verification workflows.

## Security Objectives

- Integrity: any tampering is detectable.
- Authenticity: signatures can bind artifact lineage to issuer identity.
- Replay resistance: editorial and publish decisions are traceable via receipts/policies.
- Auditability: verifiers can reproduce decisions from published artifacts.

## Trust Boundaries

- Producer boundary: creates manifest/payload/pack.
- Transport boundary: CDNs and mirrors can be untrusted.
- Consumer boundary: verifier/player must validate before trust.
- Governance boundary: policy and key lifecycle control.

## Primary Threats and Controls

| Threat | Control |
|---|---|
| Pack/header tampering | strict layout validation + bounds/alignment checks |
| Index tampering | deterministic index parse + strict sorting + padding checks |
| Payload substitution | payload hash + payload CID recomputation in full verify |
| Merkle forgery | domain-separated leaf/node hashing + root recomputation |
| Manifest anchor spoofing | mandatory envelope anchors + canonical NRF decode checks |
| Sidecar manipulation | chip envelope + signature/policy constraints in runtime |

## Required Verifier Behavior

Verifier MUST:

- validate all region boundaries and overlap constraints
- reject non-zero reserved/padding bytes where specified
- validate Merkle tree shape and root
- enforce strict manifest envelope anchors

Verifier SHOULD:

- run full payload verification in high-trust workflows
- enforce policy checks for editorial sidecar acceptance

## Key and Signature Posture

- Signature profile and key governance follow UBL trust model (`SECURITY.md`).
- VCX artifacts SHOULD use domain-separated signature contexts for manifest and pack.

## Operational Checklist

Before publication:

1. Build with strict canonical mode.
2. Run full verification.
3. Record verification result and root/cids in release evidence.
4. Store artifacts and evidence in immutable release location.

## Residual Risks

- Compromised signer keys remain a high-impact risk without rapid revocation.
- Trust policy misconfiguration can permit unsafe advisory use.
- Cross-implementation parser inconsistencies remain possible until interop testing scales.
