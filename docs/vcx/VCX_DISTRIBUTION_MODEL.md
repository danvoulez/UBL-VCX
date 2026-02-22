# VCX Distribution Model

`UBL-VCX` supports two distribution modes in the same repository.

## 1) Standalone VCX binaries

For users that want full VCX tooling directly:

- `vcx_pack_cli`
- `vcx_enc_cli`

Artifact format:

- `ubl-vcx-binaries-v<version>-<target>.tar.gz`

## 2) ublx complement package

For users that already run `UBL-CORE` + `ublx` and only need VCX features as an add-on.

Artifact format:

- `ublx-extension-vcx-v<version>-<target>.tar.gz`

Package contents:

- `extension.toml`
- `README.md`
- `bin/vcx_pack_cli`
- `bin/vcx_enc_cli`

Local installation helper:

```bash
make vcx-install-extension ARTIFACT=dist/ublx-extension-vcx-v0.1.0-<target>.tar.gz
```

## Packaging command

```bash
make vcx-package VERSION=0.1.0
```

Optional target triple:

```bash
make vcx-package VERSION=0.1.0 TARGET=x86_64-unknown-linux-gnu
```

Build output:

- `/dist/ubl-vcx-binaries-v<version>-<target>.tar.gz`
- `/dist/ubl-vcx-binaries-v<version>-<target>.tar.gz.sha256`
- `/dist/ublx-extension-vcx-v<version>-<target>.tar.gz`
- `/dist/ublx-extension-vcx-v<version>-<target>.tar.gz.sha256`

## Release strategy

Use one release tag per VCX version and publish both artifacts in the same GitHub release.

This keeps one canonical source tree while serving both audiences:

- product teams that need full VCX binaries;
- `ublx` users that need a lightweight complement package.
