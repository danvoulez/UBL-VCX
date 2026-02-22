.PHONY: help install-binary bootstrap start stop restart status logs save smoke update-core vcx-check vcx-conformance vcx-package vcx-package-binaries vcx-package-extension vcx-install-extension

help:
	@echo "Targets:"
	@echo "  make install-binary      # install/update ubl-gate binary from UBL-CORE"
	@echo "  make bootstrap           # install binary + start PM2"
	@echo "  make start               # pm2 start"
	@echo "  make stop                # pm2 stop"
	@echo "  make restart             # pm2 restart"
	@echo "  make status              # pm2 status"
	@echo "  make logs                # pm2 logs"
	@echo "  make save                # pm2 save"
	@echo "  make smoke               # API smoke test"
	@echo "  make update-core REF=vX.Y.Z"
	@echo "  make vcx-check           # cargo check VCX tooling workspace"
	@echo "  make vcx-conformance     # run VCX conformance vectors"
	@echo "  make vcx-package VERSION=vX.Y.Z [TARGET=triple]"
	@echo "  make vcx-package-binaries VERSION=vX.Y.Z [TARGET=triple]"
	@echo "  make vcx-package-extension VERSION=vX.Y.Z [TARGET=triple]"
	@echo "  make vcx-install-extension ARTIFACT=<path-or-url> [DEST=~/.ublx/extensions/vcx]"

install-binary:
	./scripts/install_binary.sh

bootstrap:
	./scripts/bootstrap_pm2.sh

start:
	pm2 start ./pm2/ecosystem.config.cjs --only ubl-gate

stop:
	pm2 stop ubl-gate

restart:
	pm2 restart ubl-gate

status:
	pm2 status

logs:
	pm2 logs ubl-gate --lines 200

save:
	pm2 save

smoke:
	./scripts/smoke.sh

update-core:
	@test -n "$(REF)" || (echo "use: make update-core REF=vX.Y.Z" && exit 1)
	./scripts/update_refs.sh core "$(REF)"

vcx-check:
	cd vcx-pack && cargo check --workspace

vcx-conformance:
	./scripts/vcx_conformance.sh --report-file docs/vcx/conformance/reports/latest.json

vcx-package:
	@test -n "$(VERSION)" || (echo "use: make vcx-package VERSION=X.Y.Z [TARGET=triple]" && exit 1)
	./scripts/package_vcx_artifacts.sh --version "$(VERSION)" $(if $(TARGET),--target "$(TARGET)",) --mode all

vcx-package-binaries:
	@test -n "$(VERSION)" || (echo "use: make vcx-package-binaries VERSION=X.Y.Z [TARGET=triple]" && exit 1)
	./scripts/package_vcx_artifacts.sh --version "$(VERSION)" $(if $(TARGET),--target "$(TARGET)",) --mode binaries

vcx-package-extension:
	@test -n "$(VERSION)" || (echo "use: make vcx-package-extension VERSION=X.Y.Z [TARGET=triple]" && exit 1)
	./scripts/package_vcx_artifacts.sh --version "$(VERSION)" $(if $(TARGET),--target "$(TARGET)",) --mode extension

vcx-install-extension:
	@test -n "$(ARTIFACT)" || (echo "use: make vcx-install-extension ARTIFACT=<path-or-url> [DEST=...]" && exit 1)
	./scripts/install_vcx_extension.sh --artifact "$(ARTIFACT)" $(if $(DEST),--dest "$(DEST)",)
