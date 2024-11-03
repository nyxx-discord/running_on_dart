help:
	@fgrep -h "##" $(MAKEFILE_LIST) | sed -e 's/\(\:.*\#\#\)/\:\ /' | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

format: ## Run dart format
	dart format -l120 .

fix: ## Run dart fix
	dart fix --apply

analyze: ## Run dart analyze
	dart analyze

fix-project: fix analyze format ## Fix whole project

run: ## Run dev project
	docker compose up --build
