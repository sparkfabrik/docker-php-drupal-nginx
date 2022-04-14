#!/bin/sh
set -e

BASE=$(dirname "${0}")
IMAGE_NAME=${IMAGE_NAME:-sparkfabrik/docker-php-drupal-nginx}
IMAGE_TAG=${IMAGE_TAG:-1.13.6-alpine.d8}
IMAGE_USER=${IMAGE_USER:-root}
BASE_TESTS_PORT=${BASE_TESTS_PORT:-80}
OVERRIDES_NGINX_PORT=${OVERRIDES_NGINX_PORT:-4321}

print_title() {
  if [ -n "${1}" ]; then
    echo "\033[1m\033[36m${1}\033[0m\033[0m"
  fi
}

# Base Tests.
print_title "Base Tests"
${BASE}/image_verify.sh --source tests/expectations --env-file tests/envfile --http-port ${BASE_TESTS_PORT} --user "${IMAGE_USER}" ${IMAGE_NAME}:${IMAGE_TAG}
${BASE}/image_verify.sh --source tests/overrides/expectations --env-file tests/overrides/envfile --http-port ${OVERRIDES_NGINX_PORT} --user "${IMAGE_USER}" ${IMAGE_NAME}:${IMAGE_TAG}

# Catch all tests.
print_title "Catch all tests"
${BASE}/image_verify.sh --source tests/overrides/catch-all/expectations-ok --env-file tests/overrides/catch-all/envfile --http-port ${OVERRIDES_NGINX_PORT} --user "${IMAGE_USER}" --req-header-host www.domain1.com ${IMAGE_NAME}:${IMAGE_TAG}
${BASE}/image_verify.sh --source tests/overrides/catch-all/expectations-ko --env-file tests/overrides/catch-all/envfile --http-port ${OVERRIDES_NGINX_PORT} --user "${IMAGE_USER}" --req-header-host domain1.com ${IMAGE_NAME}:${IMAGE_TAG}

# CORS Tests.
print_title "CORS Tests"
${BASE}/image_verify.sh --source tests/overrides/cors/expectations-filtered-php --env-file tests/overrides/cors/envfile-filtered --http-port ${OVERRIDES_NGINX_PORT} --http-path index.php --user "${IMAGE_USER}" --cors-origin-host www.example.com ${IMAGE_NAME}:${IMAGE_TAG}
${BASE}/image_verify.sh --http-port ${OVERRIDES_NGINX_PORT} --source tests/overrides/cors/expectations-unfiltered-php --env-file tests/overrides/cors/envfile-unfiltered --http-port ${OVERRIDES_NGINX_PORT} --http-path index.php --user "${IMAGE_USER}" --cors-origin-host www.foobar.com ${IMAGE_NAME}:${IMAGE_TAG}
${BASE}/image_verify.sh --source tests/overrides/cors/expectations-filtered-png --env-file tests/overrides/cors/envfile-filtered --http-port ${OVERRIDES_NGINX_PORT} --http-path public/image.png --user "${IMAGE_USER}" --cors-origin-host www.example.com ${IMAGE_NAME}:${IMAGE_TAG}
${BASE}/image_verify.sh --source tests/overrides/cors/expectations-unfiltered-png --env-file tests/overrides/cors/envfile-unfiltered --http-port ${OVERRIDES_NGINX_PORT} --http-path public/image.png --user "${IMAGE_USER}" --cors-origin-host www.foobar.com ${IMAGE_NAME}:${IMAGE_TAG}

# Here we want to assert that CORS header is not present.
print_title "CORS Headers not present"
${BASE}/image_verify.sh \
--source tests/overrides/cors/expectations-filtered-different-domain-php \
--env-file tests/overrides/cors/envfile-filtered-different-domain \
--http-port ${OVERRIDES_NGINX_PORT} --http-path index.php --user "${IMAGE_USER}" --cors-origin-host www.foobar.com ${IMAGE_NAME}:${IMAGE_TAG} || (EXIT_CODE=$?; if [ ${EXIT_CODE} -eq 5 ]; then echo "\e[32mTests are failed, this is what we want to test\e[39m"; exit 0; elif [ ${EXIT_CODE} -eq 0 ]; then exit 99; else exit ${EXIT_CODE}; fi)

${BASE}/image_verify.sh \
--source tests/overrides/cors/expectations-filtered-different-domain-png \
--env-file tests/overrides/cors/envfile-filtered-different-domain \
--http-port ${OVERRIDES_NGINX_PORT} --http-path public/image.png --user "${IMAGE_USER}" --cors-origin-host www.foobar.com ${IMAGE_NAME}:${IMAGE_TAG} || (EXIT_CODE=$?; if [ ${EXIT_CODE} -eq 5 ]; then echo "\e[32mTests are failed, this is what we want to test\e[39m"; exit 0; elif [ ${EXIT_CODE} -eq 0 ]; then exit 99; else exit ${EXIT_CODE}; fi)

# From-to-www redirect
print_title "from-to-www redirect tests"
${BASE}/image_verify.sh --source tests/overrides/from-to-www/expectations --env-file tests/overrides/from-to-www/envfile --http-port ${OVERRIDES_NGINX_PORT} --user "${IMAGE_USER}" --req-header-host domain1.com ${IMAGE_NAME}:${IMAGE_TAG}

# From-to-www redirect with related domains configured as valid server name
print_title "from-to-www redirect tests (related domains configured as valid server name)"
${BASE}/image_verify.sh --source tests/overrides/from-to-www/expectations-related-domains --env-file tests/overrides/from-to-www/envfile-related-domains --http-port ${OVERRIDES_NGINX_PORT} --user "${IMAGE_USER}" --req-header-host domain1.com ${IMAGE_NAME}:${IMAGE_TAG}

# From-to-www redirect with related domains configured as valid server name but use the non related one (redirect to non-www)
print_title "from-to-www redirect tests (related domains configured as valid server name but use the non related one [redirect to non-www])"
${BASE}/image_verify.sh --source tests/overrides/from-to-www/expectations-related-domains-domain2 --env-file tests/overrides/from-to-www/envfile-related-domains --http-port ${OVERRIDES_NGINX_PORT} --user "${IMAGE_USER}" --req-header-host www.domain2.it ${IMAGE_NAME}:${IMAGE_TAG}

# From-to-www redirect with related domains configured as valid server name but use the non related one (redirect to www)
print_title "from-to-www redirect tests (related domains configured as valid server name but use the non related one [redirect to www])"
${BASE}/image_verify.sh --source tests/overrides/from-to-www/expectations-related-domains-domain3 --env-file tests/overrides/from-to-www/envfile-related-domains --http-port ${OVERRIDES_NGINX_PORT} --user "${IMAGE_USER}" --req-header-host domain3.eu ${IMAGE_NAME}:${IMAGE_TAG}

# From-to-www redirect for 3rd/4th level
print_title "from-to-www redirect tests for 3rd/4th level"
${BASE}/image_verify.sh --source tests/overrides/from-to-www/expectations-related-domains-domain4 --env-file tests/overrides/from-to-www/envfile-related-domains --http-port ${OVERRIDES_NGINX_PORT} --user "${IMAGE_USER}" --req-header-host www.api.domain4.net ${IMAGE_NAME}:${IMAGE_TAG}

# Headers default
print_title "Only default headers (sensitive: no - drupal: yes)"
${BASE}/image_verify.sh --php-needed --source tests/overrides/headers/expectations-default --env-file tests/overrides/headers/envfile-default --http-port ${OVERRIDES_NGINX_PORT} --http-path index.php --user "${IMAGE_USER}" ${IMAGE_NAME}:${IMAGE_TAG}

# Hide drupal headers
print_title "Hide drupal headers (sensitive: no - drupal: no)"
${BASE}/image_verify.sh --php-needed --source tests/overrides/headers/expectations-hide-drupal --env-file tests/overrides/headers/envfile-hide-drupal --http-port ${OVERRIDES_NGINX_PORT} --http-path index.php --user "${IMAGE_USER}" ${IMAGE_NAME}:${IMAGE_TAG}

# Show sensitive headers
print_title "Show sensitive headers (sensitive: yes - drupal: yes)"
${BASE}/image_verify.sh --php-needed --source tests/overrides/headers/expectations-show-sensitive --env-file tests/overrides/headers/envfile-show-sensitive --http-port ${OVERRIDES_NGINX_PORT} --http-path index.php --user "${IMAGE_USER}" ${IMAGE_NAME}:${IMAGE_TAG}

# X-Frame-Options header enabled 
print_title "X-Frame-Options header Enabled (Default Value - SAMEORIGIN)"
${BASE}/image_verify.sh --php-needed --source tests/overrides/headers/expectations-x-frame-options-enabled --env-file tests/overrides/headers/envfile-x-frame-options-enabled --http-port ${OVERRIDES_NGINX_PORT} --http-path index.php --user "${IMAGE_USER}" ${IMAGE_NAME}:${IMAGE_TAG}

# X-Frame-Options header Disabled 
print_title "X-Frame-Options header Disabled"
${BASE}/image_verify.sh --php-needed --source tests/overrides/headers/expectations-x-frame-options-disabled --env-file tests/overrides/headers/envfile-x-frame-options-enabled --http-port ${OVERRIDES_NGINX_PORT} --http-path index.php --user "${IMAGE_USER}" ${IMAGE_NAME}:${IMAGE_TAG}