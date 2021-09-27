all: build test build-rootless test-rootless

build:
	docker build -f Dockerfile-1.13.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8 --build-arg user=root .
	docker build -f Dockerfile-1.17.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8 --build-arg user=root .
	docker build -f Dockerfile-1.21.1-alpine -t sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8 --build-arg user=root .

test:
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --user root sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --user root sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --user root sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8
	
	## CORS Tests.
	./tests/image_verify.sh --source tests/overrides/cors/expectations-filtered --env-file tests/overrides/cors/envfile-filtered --http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8
	CORS_ORIGIN_HOST=www.foobar.com ./tests/image_verify.sh --source tests/overrides/cors/expectations-unfiltered --env-file tests/overrides/cors/envfile-unfiltered --http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8

	## Here we want to assert that CORS header is not present.
	./tests/image_verify.sh \
	--source tests/overrides/cors/expectations-filtered-different-domain \
	--env-file tests/overrides/cors/envfile-filtered-different-domain \
	--http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8 || (EXIT_CODE=$$?; if [ $$EXIT_CODE -eq 5 ]; then exit 0; else exit $$EXIT_CODE; fi)

build-rootless:
	docker build -f Dockerfile-1.13.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8-rootless --build-arg user=1001 .
	docker build -f Dockerfile-1.17.6-alpine -t sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8-rootless --build-arg user=1001 .
	docker build -f Dockerfile-1.21.1-alpine -t sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8-rootless --build-arg user=1001 .

test-rootless:
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 8080 --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8-rootless
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.13.6-alpine.d8-rootless
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 8080 --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8-rootless
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.17.6-alpine.d8-rootless
	./tests/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port 8080 --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8-rootless
	./tests/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port 4321 --user "unknown uid 1001" sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8-rootless
	
	# CORS Tests.
	./tests/image_verify.sh --source tests/overrides/cors/expectations-filtered --env-file tests/overrides/cors/envfile-filtered --http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8
	CORS_ORIGIN_HOST=www.foobar.com ./tests/image_verify.sh --source tests/overrides/cors/expectations-unfiltered --env-file tests/overrides/cors/envfile-unfiltered --http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8

	## Here we want to assert that CORS header is not present.
	./tests/image_verify.sh \
	--source tests/overrides/cors/expectations-filtered-different-domain \
	--env-file tests/overrides/cors/envfile-filtered-different-domain \
	--http-port 80 --user root sparkfabrik/docker-php-drupal-nginx:1.21.1-alpine.d8 || (EXIT_CODE=$$?; if [ $$EXIT_CODE -eq 5 ]; then exit 0; else exit $$EXIT_CODE; fi)
