IMAGE_NAME ?= sparkfabrik/docker-php-drupal-nginx

.PHONY: shellcheck

all: build test build-rootless test-rootless

build:
	docker build -f Dockerfile-1.13.6-alpine -t $(IMAGE_NAME):1.13.6-alpine.d8 --build-arg user=root .
	docker build -f Dockerfile-1.17.6-alpine -t $(IMAGE_NAME):1.17.6-alpine.d8 --build-arg user=root .
	docker build -f Dockerfile-1.21.1-alpine -t $(IMAGE_NAME):1.21.1-alpine.d8 --build-arg user=root .
	docker build -f Dockerfile-1.21.6-alpine -t $(IMAGE_NAME):1.21.6-alpine.d8 --build-arg user=root .
	docker build -f Dockerfile-1.23.1-alpine -t $(IMAGE_NAME):1.23.1-alpine.d8 --build-arg user=root .
	docker build -f Dockerfile-1.23.3-alpine -t $(IMAGE_NAME):1.23.3-alpine.d8 --build-arg user=root .

test:
	@chmod +x ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.13.6-alpine.d8 ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.17.6-alpine.d8 ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.21.1-alpine.d8 ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.21.6-alpine.d8 ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.23.1-alpine.d8 ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.23.3-alpine.d8 ./tests/tests.sh

build-rootless:
	docker build -f Dockerfile-1.13.6-alpine -t $(IMAGE_NAME):1.13.6-alpine.d8-rootless --build-arg user=1001 .
	docker build -f Dockerfile-1.17.6-alpine -t $(IMAGE_NAME):1.17.6-alpine.d8-rootless --build-arg user=1001 .
	docker build -f Dockerfile-1.21.1-alpine -t $(IMAGE_NAME):1.21.1-alpine.d8-rootless --build-arg user=1001 .
	docker build -f Dockerfile-1.21.6-alpine -t $(IMAGE_NAME):1.21.6-alpine.d8-rootless --build-arg user=1001 .
	docker build -f Dockerfile-1.23.1-alpine -t $(IMAGE_NAME):1.23.1-alpine.d8-rootless --build-arg user=1001 .
	docker build -f Dockerfile-1.23.3-alpine -t $(IMAGE_NAME):1.23.3-alpine.d8-rootless --build-arg user=1001 .

test-rootless:
	@chmod +x ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.13.6-alpine.d8-rootless IMAGE_USER="unknown uid 1001" BASE_TESTS_PORT="8080" ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.17.6-alpine.d8-rootless IMAGE_USER="unknown uid 1001" BASE_TESTS_PORT="8080" ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.21.1-alpine.d8-rootless IMAGE_USER="unknown uid 1001" BASE_TESTS_PORT="8080" ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.21.6-alpine.d8-rootless IMAGE_USER="unknown uid 1001" BASE_TESTS_PORT="8080" ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.23.1-alpine.d8-rootless IMAGE_USER="unknown uid 1001" BASE_TESTS_PORT="8080" ./tests/tests.sh
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=1.23.3-alpine.d8-rootless IMAGE_USER="unknown uid 1001" BASE_TESTS_PORT="8080" ./tests/tests.sh

shellcheck-build:
	@docker build -f shellcheck/Dockerfile -t sparkfabrik/shellchek shellcheck

shellcheck: shellcheck-build
	@docker run --rm -it -w /app -v $${PWD}:/app sparkfabrik/shellchek
