all: build build-rootless

build:
	docker build -f Dockerfile-1.13.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8 --build-arg user=root .
	docker build -f Dockerfile-1.17.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8 --build-arg user=root .

build-rootless:
	docker build -f Dockerfile-1.13.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8-rootless --build-arg user=1001 .
	docker build -f Dockerfile-1.17.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8-rootless --build-arg user=1001 .
