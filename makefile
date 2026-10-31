source_env_file:
	@echo "run manually: 'set -a && source .env && set +a'"
	@echo "NOTICE: this will be per terminal session"

setup:
	@echo "+ bash scripts/setup.bash"
	@bash scripts/setup.bash
