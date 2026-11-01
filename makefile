source-env-file:
	@echo "run manually: 'set -a && source .env && set +a'"
	@echo "NOTICE: this will be per terminal session"

setup-local-project-deps:
	@echo "+ bash scripts/tools/setup-local-project-deps.bash"
	@bash scripts/tools/setup-local-project-deps.bash

terraform-bootstrap-state-bucket:
	@echo "+ bash scripts/one-time/bootstrap-terraform-state-bucket.bash"
	@bash scripts/one-time/bootstrap-terraform-state-bucket.bash

terraform-init:
	terraform -chdir=infrastructure/provisioning/terraform init \
		-backend-config="bucket=$$TF_STATE_BUCKET" \
		-backend-config="region=$$AWS_REGION"

terraform-plan:
	terraform -chdir=infrastructure/provisioning/terraform plan

terraform-apply:
	terraform -chdir=infrastructure/provisioning/terraform apply

terraform-destroy:
	terraform -chdir=infrastructure/provisioning/terraform destroy

terraform-output:
	terraform -chdir=infrastructure/provisioning/terraform output name_servers > .env.name_servers
	terraform -chdir=infrastructure/provisioning/terraform output zone_id > .env.zone_id