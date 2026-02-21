.PHONY: help install-binary bootstrap start stop restart status logs save smoke update-multi update-core

help:
	@echo "Targets:"
	@echo "  make install-binary      # install/update ubl-gate binary from UBL-MULTI"
	@echo "  make bootstrap           # install binary + start PM2"
	@echo "  make start               # pm2 start"
	@echo "  make stop                # pm2 stop"
	@echo "  make restart             # pm2 restart"
	@echo "  make status              # pm2 status"
	@echo "  make logs                # pm2 logs"
	@echo "  make save                # pm2 save"
	@echo "  make smoke               # API smoke test"
	@echo "  make update-multi REF=vX.Y.Z"
	@echo "  make update-core REF=vX.Y.Z"

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

update-multi:
	@test -n "$(REF)" || (echo "use: make update-multi REF=vX.Y.Z" && exit 1)
	./scripts/update_refs.sh multi "$(REF)"

update-core:
	@test -n "$(REF)" || (echo "use: make update-core REF=vX.Y.Z" && exit 1)
	./scripts/update_refs.sh core "$(REF)"
