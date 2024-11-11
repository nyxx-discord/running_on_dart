help:
	@fgrep -h "##" $(MAKEFILE_LIST) | sed -e 's/\(\:.*\#\#\)/\:\ /' | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

format: ## Run dart format
	dart format -l120 .

fix: ## Run dart fix
	dart fix --apply

analyze: ## Run dart analyze
	dart analyze

tests: ## Run unit tests
	dart run test

fix-project: analyze fix format ## Fix whole project

check-project: fix-project tests ## Run all checks
