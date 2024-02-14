#!/bin/bash
# shellcheck disable=3037

set -e

BASE="$(dirname "${0}")"
IMAGE_NAME=${IMAGE_NAME:-sparkfabrik/docker-php-drupal-nginx}
IMAGE_TAG=${IMAGE_TAG:-1.13.6-alpine.d8}
IMAGE_USER=${IMAGE_USER:-root}
BASE_TESTS_PORT=${BASE_TESTS_PORT:-80}
OVERRIDES_NGINX_PORT=${OVERRIDES_NGINX_PORT:-4321}

print_title() {
  if [ -n "${1}" ]; then
    echo -e "\033[1m\033[36m${1}\033[0m\033[0m"
  fi
}

# Base Tests.
print_title "Base Tests"
"${BASE}/image_verify.sh" --source "${BASE}/expectations" --env-file "${BASE}/envfile" --http-port "${BASE_TESTS_PORT}" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/expectations" --env-file "${BASE}/overrides/envfile" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

# Catch all tests.
print_title "Catch all tests"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/catch-all/expectations-ok" --env-file "${BASE}/overrides/catch-all/envfile" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host www.domain1.com "${IMAGE_NAME}:${IMAGE_TAG}"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/catch-all/expectations-ko" --env-file "${BASE}/overrides/catch-all/envfile" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host domain1.com "${IMAGE_NAME}:${IMAGE_TAG}"

# CORS Tests.
print_title "CORS Tests"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/cors/expectations-filtered-php" --env-file "${BASE}/overrides/cors/envfile-filtered" --http-port "${OVERRIDES_NGINX_PORT}" --http-path index.php --user "${IMAGE_USER}" --cors-origin-host www.example.com "${IMAGE_NAME}:${IMAGE_TAG}"
"${BASE}/image_verify.sh" --http-port "${OVERRIDES_NGINX_PORT}" --source "${BASE}/overrides/cors/expectations-unfiltered-php" --env-file "${BASE}/overrides/cors/envfile-unfiltered" --http-port "${OVERRIDES_NGINX_PORT}" --http-path index.php --user "${IMAGE_USER}" --cors-origin-host www.foobar.com "${IMAGE_NAME}:${IMAGE_TAG}"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/cors/expectations-filtered-png" --env-file "${BASE}/overrides/cors/envfile-filtered" --http-port "${OVERRIDES_NGINX_PORT}" --http-path public/image.png --user "${IMAGE_USER}" --cors-origin-host www.example.com "${IMAGE_NAME}:${IMAGE_TAG}"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/cors/expectations-unfiltered-png" --env-file "${BASE}/overrides/cors/envfile-unfiltered" --http-port "${OVERRIDES_NGINX_PORT}" --http-path public/image.png --user "${IMAGE_USER}" --cors-origin-host www.foobar.com "${IMAGE_NAME}:${IMAGE_TAG}"

# Here we want to assert that CORS header is not present.
print_title "CORS Headers not present"
"${BASE}/image_verify.sh" \
  --source "${BASE}/overrides/cors/expectations-filtered-different-domain-php" \
  --env-file "${BASE}/overrides/cors/envfile-filtered-different-domain" \
  --http-port "${OVERRIDES_NGINX_PORT}" --http-path index.php --user "${IMAGE_USER}" --cors-origin-host www.foobar.com "${IMAGE_NAME}:${IMAGE_TAG}" || (
  EXIT_CODE=$?
  if [ ${EXIT_CODE} -eq 5 ]; then
    printf "\e[32mTests are failed, this is what we want to test\e[39m"
    exit 0
  elif [ ${EXIT_CODE} -eq 0 ]; then exit 99; else exit ${EXIT_CODE}; fi
)

"${BASE}/image_verify.sh" \
  --source "${BASE}/overrides/cors/expectations-filtered-different-domain-png" \
  --env-file "${BASE}/overrides/cors/envfile-filtered-different-domain" \
  --http-port "${OVERRIDES_NGINX_PORT}" --http-path public/image.png --user "${IMAGE_USER}" --cors-origin-host www.foobar.com "${IMAGE_NAME}:${IMAGE_TAG}" || (
  EXIT_CODE=$?
  if [ ${EXIT_CODE} -eq 5 ]; then
    printf "\e[32mTests are failed, this is what we want to test\e[39m"
    exit 0
  elif [ ${EXIT_CODE} -eq 0 ]; then exit 99; else exit ${EXIT_CODE}; fi
)

# From-to-www redirect
print_title "from-to-www redirect tests"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/from-to-www/expectations" --env-file "${BASE}/overrides/from-to-www/envfile" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host domain1.com "${IMAGE_NAME}:${IMAGE_TAG}"

# From-to-www redirect with related domains configured as valid server name
print_title "from-to-www redirect tests (related domains configured as valid server name)"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/from-to-www/expectations-related-domains" --env-file "${BASE}/overrides/from-to-www/envfile-related-domains" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host domain1.com "${IMAGE_NAME}:${IMAGE_TAG}"

# From-to-www redirect with related domains configured as valid server name but use the non related one (redirect to non-www)
print_title "from-to-www redirect tests (related domains configured as valid server name but use the non related one [redirect to non-www])"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/from-to-www/expectations-related-domains-domain2" --env-file "${BASE}/overrides/from-to-www/envfile-related-domains" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host www.domain2.it "${IMAGE_NAME}:${IMAGE_TAG}"

# From-to-www redirect with related domains configured as valid server name but use the non related one (redirect to www)
print_title "from-to-www redirect tests (related domains configured as valid server name but use the non related one [redirect to www])"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/from-to-www/expectations-related-domains-domain3" --env-file "${BASE}/overrides/from-to-www/envfile-related-domains" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host domain3.eu "${IMAGE_NAME}:${IMAGE_TAG}"

# From-to-www redirect for 3rd/4th level
print_title "from-to-www redirect tests for 3rd/4th level"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/from-to-www/expectations-related-domains-domain4" --env-file "${BASE}/overrides/from-to-www/envfile-related-domains" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host www.api.domain4.net "${IMAGE_NAME}:${IMAGE_TAG}"

# Headers default
print_title "Only default headers (sensitive: no - drupal: yes)"
"${BASE}/image_verify.sh" --php-needed --source "${BASE}/overrides/headers/expectations-default" --env-file "${BASE}/overrides/headers/envfile-default" --http-port "${OVERRIDES_NGINX_PORT}" --http-path index.php --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

# Hide drupal headers
print_title "Hide drupal headers (sensitive: no - drupal: no)"
"${BASE}/image_verify.sh" --php-needed --source "${BASE}/overrides/headers/expectations-show-drupal" --env-file "${BASE}/overrides/headers/envfile-show-drupal" --http-port "${OVERRIDES_NGINX_PORT}" --http-path index.php --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

# Show sensitive headers
print_title "Show sensitive headers (sensitive: yes - drupal: yes)"
"${BASE}/image_verify.sh" --php-needed --source "${BASE}/overrides/headers/expectations-show-sensitive" --env-file "${BASE}/overrides/headers/envfile-show-sensitive" --http-port "${OVERRIDES_NGINX_PORT}" --http-path index.php --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

# X-Frame-Options header enabled
print_title "X-Frame-Options header Enabled (Default Value - SAMEORIGIN)"
"${BASE}/image_verify.sh" --php-needed --source "${BASE}/overrides/headers/expectations-x-frame-options-enabled" --env-file "${BASE}/overrides/headers/envfile-x-frame-options-enabled" --http-port "${OVERRIDES_NGINX_PORT}" --http-path index.php --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

# HSTS enabled
print_title "HSTS header Enabled"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/headers/expectations-hsts-enabled" --env-file "${BASE}/overrides/headers/envfile-hsts-enabled" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

# HSTS no preload (max-age=63072000; includeSubDomains)
print_title "HSTS header Enabled without preload"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/headers/expectations-hsts-no-preload" --env-file "${BASE}/overrides/headers/envfile-hsts-no-preload" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

# HSTS no subdomains (max-age=63072000; preload)
print_title "HSTS header Enabled without includeSubDomains"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/headers/expectations-hsts-no-subdomains" --env-file "${BASE}/overrides/headers/envfile-hsts-no-subdomains" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

# HSTS related domains (max-age=63072000; preload)
print_title "HSTS header related domains"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/headers/expectations-hsts-related-domains" --env-file "${BASE}/overrides/headers/envfile-hsts-related-domains" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host domain1.com "${IMAGE_NAME}:${IMAGE_TAG}"

# HSTS header catch all tests
print_title "HSTS header catch all tests"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/headers/expectations-hsts-catch-all-expectations-ok" --env-file "${BASE}/overrides/headers/envfile-hsts-catch-all" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host www.domain1.com "${IMAGE_NAME}:${IMAGE_TAG}"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/headers/expectations-hsts-catch-all-expectations-ko" --env-file "${BASE}/overrides/headers/envfile-hsts-catch-all" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" --req-header-host domain1.com "${IMAGE_NAME}:${IMAGE_TAG}"

# CSP header tests
print_title "CSP header tests"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/headers/expectations-csp-enabled" --env-file "${BASE}/overrides/headers/envfile-csp-enabled" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

print_title "Environment verify"
"${BASE}/image_verify_env.sh" --source "${BASE}/overrides/osb_bucket/expectations" --env-file "${BASE}/overrides/osb_bucket/envfile" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

# Basic Auth Test
print_title "Basic Auth Test - No auth configured"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/basic-auth/expectations-ko" --env-file "${BASE}/overrides/basic-auth/envfile-ko" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

print_title "Basic Auth Test - No auth configured but location is not protected"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/basic-auth/expectations-ok-location" --env-file "${BASE}/overrides/basic-auth/envfile-ok-location" --http-port "${OVERRIDES_NGINX_PORT}" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"

print_title "Basic Auth Test - Auth configured"
"${BASE}/image_verify.sh" --source "${BASE}/overrides/basic-auth/expectations-ok" --env-file "${BASE}/overrides/basic-auth/envfile-ok" --http-port "${OVERRIDES_NGINX_PORT}" --req-header-auth "user:pass" --user "${IMAGE_USER}" "${IMAGE_NAME}:${IMAGE_TAG}"
