all: build build-rootless

build:
	docker build -f Dockerfile-1.13.6-alpine -t sparkfabik/docker-php-drupal-nginx:1.13.6-alpine --build-arg user=root .
	docker build -f Dockerfile-1.17.6-alpine -t sparkfabik/docker-php-drupal-nginx:1.17.6-alpine --build-arg user=root .

build-rootless:
	docker build -f Dockerfile-1.13.6-alpine -t sparkfabik/docker-php-drupal-nginx:1.13.6-alpine-rootless --build-arg user=nginx .
	docker build -f Dockerfile-1.17.6-alpine -t sparkfabik/docker-php-drupal-nginx:1.17.6-alpine-rootless --build-arg user=nginx .
