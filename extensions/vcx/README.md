# VCX Extension Package

This folder defines the distributable complement package for `ublx`.

Package layout produced by release scripts:

- `extension.toml`: metadata and command registry.
- `bin/vcx_pack_cli`: deterministic pack/verify CLI.
- `bin/vcx_enc_cli`: deterministic media-to-VCX encoder CLI.

The generated tarball can be consumed by future `ublx` extension-install flow
without requiring any source-code vendoring.
