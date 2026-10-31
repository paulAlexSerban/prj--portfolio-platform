source-env-file:
	@echo "run manually: 'set -a && source .env && set +a'"
	@echo "NOTICE: this will be per terminal session"

setup-local-project-deps:
	@echo "+ bash scripts/setup-local-project-deps.bash"
	@bash scripts/setup-local-project-deps.bash
