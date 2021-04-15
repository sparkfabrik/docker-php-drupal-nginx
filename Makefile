all: build test build-rootless test-rootless

build:
	docker build -f Dockerfile-1.13.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8 --build-arg user=root .
	docker build -f Dockerfile-1.17.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8 --build-arg user=root .

test:
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --http-host nginx_default_server_name --user root sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --http-host nginx_default_server_name --user root sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8

build-rootless:
	docker build -f Dockerfile-1.13.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8-rootless --build-arg user=1001 .
	docker build -f Dockerfile-1.17.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8-rootless --build-arg user=1001 .

test-rootless:
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 8080 --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8-rootless
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --http-host nginx_default_server_name --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8-rootless
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 8080 --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8-rootless
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --http-host nginx_default_server_name --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8-rootless
