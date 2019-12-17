all: build

build:
	docker rm -vf docker-php-drupal-nginx || true
	docker build -t sparkfabrik/docker-php-drupal-nginx  .
	docker run -d --name docker-php-drupal-nginx -e PHP_HOST=localhost -e PHP_PORT=80 sparkfabrik/docker-php-drupal-nginx
