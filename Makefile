all: build

build:
	docker build -t sparkfabik/docker-php-drupal-nginx:1.13.6-alpine .
	docker build -t sparkfabik/docker-php-drupal-nginx:1.17.6-alpine .
