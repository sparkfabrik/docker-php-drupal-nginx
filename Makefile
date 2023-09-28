# Add tags for the official nginx image to build
IMAGE_TAGS ?= 1.13.6-alpine \
	1.17.6-alpine \
	1.21.1-alpine \
	1.21.6-alpine \
	1.23.1-alpine \
	1.23.3-alpine \
	1.23.3-alpine-slim \
	1.25.1-alpine-slim

IMAGE_NAME ?= sparkfabrik/docker-php-drupal-nginx

.PHONY: shellcheck

all: build test build-rootless test-rootless

build: BUILD_IMAGE_USER=root
build: BUILD_IMAGE_TAG_SUFFIX=d8
build: build-template

build-rootless: BUILD_IMAGE_USER=1001
build-rootless: BUILD_IMAGE_TAG_SUFFIX=d8-rootless
build-rootless: build-template

build-template:
	@if [ -z "$(BUILD_IMAGE_USER)" ]; then echo "[build-template] BUILD_IMAGE_USER is not set"; exit 1; fi
	@if [ -z "$(BUILD_IMAGE_TAG_SUFFIX)" ]; then echo "[build-template] BUILD_IMAGE_TAG_SUFFIX is not set"; exit 1; fi
	@for NGINX_IMAGE_TAG in $(IMAGE_TAGS); do \
		NGINX_IMAGE_TAG=$${NGINX_IMAGE_TAG} BUILD_IMAGE_TAG_SUFFIX=$(BUILD_IMAGE_TAG_SUFFIX) BUILD_IMAGE_USER=$(BUILD_IMAGE_USER) $(MAKE) base-build-template; \
	done

base-build-template:
	@if [ -z "$(NGINX_IMAGE_TAG)" ]; then echo "[base-build-template] NGINX_IMAGE_TAG is not set"; exit 1; fi
	@if [ -z "$(BUILD_IMAGE_TAG_SUFFIX)" ]; then echo "[base-build-template] BUILD_IMAGE_TAG_SUFFIX is not set"; exit 1; fi
	@if [ -z "$(BUILD_IMAGE_USER)" ]; then echo "[base-build-template] BUILD_IMAGE_USER is not set"; exit 1; fi
	docker build -f Dockerfile -t $(IMAGE_NAME):$(NGINX_IMAGE_TAG).$(BUILD_IMAGE_TAG_SUFFIX) --build-arg NGINX_IMAGE_TAG=$(NGINX_IMAGE_TAG) --build-arg user=$(BUILD_IMAGE_USER) .

test: IMAGE_TAG_SUFFIX=d8
test: ADDITIONAL_PARAMS=""
test: test-template

test-rootless: IMAGE_TAG_SUFFIX=d8-rootless
test-rootless: ADDITIONAL_PARAMS="IMAGE_USER=\"unknown uid 1001\" BASE_TESTS_PORT=\"8080\""
test-rootless: test-template

test-template:
	@chmod +x ./tests/tests.sh
	@for NGINX_IMAGE_TAG in $(IMAGE_TAGS); do \
		ADDITIONAL_PARAMS=$(ADDITIONAL_PARAMS) IMAGE_TAG=$${NGINX_IMAGE_TAG}.$(IMAGE_TAG_SUFFIX) $(MAKE) base-test-template; \
	done

base-test-template: ADDITIONAL_PARAMS ?= ""
base-test-template:
	@if [ -z "$(IMAGE_NAME)" ]; then echo "[base-test-template] IMAGE_NAME is not set"; exit 1; fi
	@if [ -z "$(IMAGE_TAG)" ]; then echo "[base-test-template] IMAGE_TAG is not set"; exit 1; fi
	IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=$(IMAGE_TAG) $(ADDITIONAL_PARAMS) ./tests/tests.sh

shellcheck-build:
	@docker build -f shellcheck/Dockerfile -t sparkfabrik/shellchek shellcheck

shellcheck: shellcheck-build
	@docker run --rm -it -w /app -v $${PWD}:/app sparkfabrik/shellchek
