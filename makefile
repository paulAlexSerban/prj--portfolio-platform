source-env-file:
	@echo "run manually: 'set -a && source .env && set +a'"
	@echo "NOTICE: this will be per terminal session"

setup-local-project-deps:
	@echo "+ bash scripts/tools/setup-local-project-deps.bash"
	@bash scripts/tools/setup-local-project-deps.bash

terraform-bootstrap-state-bucket:
	@echo "+ bash scripts/one-time/bootstrap-terraform-state-bucket.bash"
	@bash scripts/one-time/bootstrap-terraform-state-bucket.bash

terraform-portfolio-plan-init:
	terraform -chdir=infrastructure/provisioning/terraform init \
		-backend-config="bucket=$$TF_STATE_BUCKET" \
		-backend-config="region=$$AWS_REGION"

terraform-portfolio-plan-plan:
	terraform -chdir=infrastructure/provisioning/terraform plan

terraform-portfolio-plan-apply:
	terraform -chdir=infrastructure/provisioning/terraform apply

terraform-portfolio-plan-destroy:
	terraform -chdir=infrastructure/provisioning/terraform destroy

terraform-portfolio-plan-output:
	terraform -chdir=infrastructure/provisioning/terraform output name_servers > .env.name_servers
	terraform -chdir=infrastructure/provisioning/terraform output zone_id > .env.zone_id