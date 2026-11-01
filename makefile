DNS_ZONE_STACK ?= layers/01-foundation/terraform/dns-zone
OIDC_STACK ?= layers/01-foundation/terraform/github-oidc-provider
STATIC_SITES_STACK ?= layers/05-workloads/terraform/static-sites

# Certificates and their validation CNAMEs only. Does not attach hostnames
# and does not wait for issuance. Run the copy script next.
STATIC_SITES_CERT_TARGETS := \
	-target=module.static_site.aws_acm_certificate.site \
	-target=module.static_site.aws_route53_record.cert_validation \
	-target=module.static_site_blog.aws_acm_certificate.site \
	-target=module.static_site_blog.aws_route53_record.cert_validation \
	-target=module.static_site_quiz.aws_acm_certificate.site \
	-target=module.static_site_quiz.aws_route53_record.cert_validation \
	-target=module.static_site_news.aws_acm_certificate.site \
	-target=module.static_site_news.aws_route53_record.cert_validation \
	-target=module.news_data_cdn.aws_acm_certificate.data \
	-target=module.news_data_cdn.aws_route53_record.cert_validation

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

terraform-oidc-init:
	terraform -chdir=$(OIDC_STACK) init \
		-backend-config="bucket=$$TF_STATE_BUCKET" \
		-backend-config="region=$$AWS_REGION"

terraform-oidc-plan:
	terraform -chdir=$(OIDC_STACK) plan

terraform-oidc-apply:
	terraform -chdir=$(OIDC_STACK) apply

terraform-static-sites-init:
	terraform -chdir=$(STATIC_SITES_STACK) init \
		-backend-config="bucket=$$TF_STATE_BUCKET" \
		-backend-config="region=$$AWS_REGION"

terraform-static-sites-plan:
	terraform -chdir=$(STATIC_SITES_STACK) plan

terraform-static-sites-apply:
	terraform -chdir=$(STATIC_SITES_STACK) apply

terraform-static-sites-output:
	terraform -chdir=$(STATIC_SITES_STACK) output

terraform-static-sites-certs:
	terraform -chdir=$(STATIC_SITES_STACK) apply $(STATIC_SITES_CERT_TARGETS)

sync-github-env-vars:
	@bash scripts/tools/sync-github-env-vars.bash
