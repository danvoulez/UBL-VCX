# UBL-VCX Release Model

`UBL-VCX` publishes a dual artifact release from the same repository:

- Standalone VCX binaries for direct usage.
- VCX complement package for `ublx` extension workflows.

## Versioning

- Tag format: `vcx-vX.Y.Z`
- Example: `vcx-v0.1.0`

## Artifacts

Per target platform, release includes:

- `ubl-vcx-binaries-vX.Y.Z-<target>.tar.gz`
- `ubl-vcx-binaries-vX.Y.Z-<target>.tar.gz.sha256`
- `ublx-extension-vcx-vX.Y.Z-<target>.tar.gz`
- `ublx-extension-vcx-vX.Y.Z-<target>.tar.gz.sha256`

## Local packaging

```bash
make vcx-package VERSION=0.1.0
```
