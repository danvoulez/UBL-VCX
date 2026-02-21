# vcx_enc_cli

Deterministic MP4 -> VCX encoder wired to UBL canonical pipeline:

- manifest envelope anchors (`@type`, `@id`, `@ver`, `@world`)
- strict UNC-1 numeric objects in manifest (unless `--no-strict-unc1`)
- deterministic payload CID rule from `vcx_pack`
- final `verify --full` executed after build

## Basic use

```bash
cargo run -p vcx_enc_cli -- \
  --input /path/video.mp4 \
  --out /path/video.vcx \
  --world a/demo/t/prod \
  --max-frames 8 \
  --manifest-out /path/video.manifest.json
```

## Notes

- Current IC0 payload profile is `VCX-IC0-ALPHA` (deterministic luma-tile payloads, tile default `64x64`).
- Audio is optionally extracted as deterministic Opus payload (`audio/opus`) when source has an audio stream.
- The generated pack is immediately self-validated with full verification.
