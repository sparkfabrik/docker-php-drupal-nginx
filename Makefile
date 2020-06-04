all: build

build:
	docker build -f Dockerfile-1.13.6-alpine -t sparkfabik/docker-php-drupal-nginx:1.13.6-alpine .
	docker build -f Dockerfile-1.17.6-alpine -t sparkfabik/docker-php-drupal-nginx:1.17.6-alpine .
