# VCX Benchmark Profile (v1)

**Status**: active
**Owner**: Core Runtime
**Last reviewed**: 2026-02-20

## Purpose

Define reproducible performance measurements for VCX implementations.

## Metrics

- Pack build latency (p50/p95/p99)
- Verify latency (normal and full)
- Throughput (packs/sec, MB/sec)
- CPU and memory profile
- Pack size and payload overhead

## Environment Contract

- CPU model and core count
- RAM size
- OS version
- Compiler/runtime version
- Dataset description

## Benchmark Scenarios

1. Small pack (1 payload)
2. Medium pack (100 payloads)
3. Large pack (10k payloads)
4. Negative verification (corrupted inputs)

## Reporting Format

| Scenario | Build p95 (ms) | Verify p95 (ms) | Full Verify p95 (ms) | Throughput | Notes |
|---|---|---|---|---|---|

All published benchmark runs MUST include environment details and command lines.
