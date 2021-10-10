.PHONY: help
help:
	@fgrep -h "##" $(MAKEFILE_LIST) | sed -e 's/\(\:.*\#\#\)/\:\ /' | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

.PHONY: build
build: ## build images
	docker compose build

.PHONY: build-no-cache
build-no-cache: ## build images discarding cache
	docker compose build --no-cache

.PHONY: stop
stop: ## stop images
	docker compose down

.PHONY: start
start: build ## start images from docker compose
	docker compose up

.PHONY: clean
clean: stop ## clean container created by docker compose
	docker compose rm

.PHONY: clean-start
clean-start: clean build-no-cache start ## cleans cache, build discarding cache and start dockers
