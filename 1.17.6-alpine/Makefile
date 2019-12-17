all: build

build:
	docker rm -vf docker-php-drupal-nginx-1.17.6 || true
	docker build -t sparkfabrik/docker-php-drupal-nginx:1.17.6  .
	docker run -d --name docker-php-drupal-nginx-1.17.6 -e PHP_HOST=localhost -e PHP_PORT=80 sparkfabrik/docker-php-drupal-nginx
