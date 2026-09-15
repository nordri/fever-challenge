APP_DIR         ?= fever-challenge
VERSION_FILE    ?= version.txt

IMAGE_NAME      ?= fever-client
IMAGE_TAG       ?= $(shell cat $(VERSION_FILE))
CONTAINER_NAME  ?= fever-client
HOST_PORT       ?= 5000
CONTAINER_PORT  ?= 5000
ENV_FILE        ?= .env
DOCKER_NETWORK  ?= docker-compose_default

IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)

export PYTHONPATH := fever-challenge

.PHONY: build run rm version

version:
	@echo $(IMAGE_TAG)

build:
	docker build \
		--label org.opencontainers.image.version=$(IMAGE_TAG) \
		-t $(IMAGE) \
		.

run:
	docker run -d \
		--name $(CONTAINER_NAME) \
		--network $(DOCKER_NETWORK) \
		--env-file $(ENV_FILE) \
		-p $(HOST_PORT):$(CONTAINER_PORT) \
		$(IMAGE)

rm:
	-docker rm -f $(CONTAINER_NAME)
