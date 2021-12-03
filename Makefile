.PHONY: help
help:
	@fgrep -h "##" $(MAKEFILE_LIST) | sed -e 's/\(\:.*\#\#\)/\:\ /' | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

.PHONY: build
build: ## build images
	docker build .

.PHONY: build-no-cache
build-no-cache: ## build images discarding cache
	docker build .

.PHONY: stop
stop: ## stop images
	docker compose down

.PHONY: start
start: ## start images from docker compose
	docker compose up

.PHONY: clean
clean: stop ## clean container created by docker compose
	docker compose rm

.PHONY: clean-start
clean-start: clean build-no-cache start ## cleans cache, build discarding cache and start dockers

.PHONY: format
format: ## Run dart format
	dart format --set-exit-if-changed -l 160 ./lib ./bin

.PHONY: format-apply
format-apply: ## Run dart format
	dart format --fix -l 160 ./lib ./bin

.PHONY: analyze
analyze: ## Run dart analyze
	dart analyze

.PHONY: prod-start
prod-start: ## build and start prod docker-compose
	docker-compose -f docker-compose.prod.yml up -d

.PHONY: prod-start-build
prod-start-build: ## build and start prod docker-compose
	docker-compose -f docker-compose.prod.yml up -d --build

.PHONY: prod-stop
prod-stop: ## build and start prod docker-compose
	docker-compose -f docker-compose.prod.yml down
