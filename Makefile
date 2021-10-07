.PHONY: help
help:
	@fgrep -h "##" $(MAKEFILE_LIST) | sed -e 's/\(\:.*\#\#\)/\:\ /' | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

build: ## build images
	docker compose build

build-no-cache: ## build images discarding cache
	docker compose build --no-cache

stop: ## stop images
	docker compose down

start: ## start images from docker compose
	docker compose up

clean: stop ## clean container created by docker compose
	docker compose rm

clean-start: clean build-no-cache start ## cleans cache, build discarding cache and start dockers
