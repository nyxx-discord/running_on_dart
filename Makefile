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

run: ## Run dev project
	docker compose up --build

upgrade: ## Run dart pub upgrade
	dart pub upgrade

build-frontend-dev: ## Build dev frontend
	cd frontend/; env-cmd -f .env.development.local yarn build
	cp -r frontend/build/** public/

fix-project: fix analyze format ## Fix whole project

check-project: fix-project tests ## Run all checks
