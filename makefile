DNS_ZONE_STACK ?= layers/01-foundation/terraform/dns-zone

source-env-file:
	@echo "run manually: 'set -a && source .env && set +a'"
	@echo "NOTICE: this will be per terminal session"

setup-local-project-deps:
	@echo "+ bash scripts/tools/setup-local-project-deps.bash"
	@bash scripts/tools/setup-local-project-deps.bash

terraform-bootstrap-state-bucket:
	@echo "+ bash layers/01-foundation/bootstrap/bootstrap-terraform-state-bucket.bash"
	@bash layers/01-foundation/bootstrap/bootstrap-terraform-state-bucket.bash

terraform-dns-zone-init:
	terraform -chdir=$(DNS_ZONE_STACK) init \
		-backend-config="bucket=$$TF_STATE_BUCKET" \
		-backend-config="region=$$AWS_REGION"

terraform-dns-zone-plan:
	terraform -chdir=$(DNS_ZONE_STACK) plan

terraform-dns-zone-apply:
	terraform -chdir=$(DNS_ZONE_STACK) apply

terraform-dns-zone-destroy:
	terraform -chdir=$(DNS_ZONE_STACK) destroy

terraform-dns-zone-output:
	terraform -chdir=$(DNS_ZONE_STACK) output name_servers > .env.name_servers
	terraform -chdir=$(DNS_ZONE_STACK) output zone_id > .env.zone_id
