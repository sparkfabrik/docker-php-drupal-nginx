#!/bin/sh
export PHP_HOST=${PHP_HOST:-php}
export PHP_PORT=${PHP_PORT:-9000}
export NGINX_PHP_READ_TIMEOUT=${NGINX_PHP_READ_TIMEOUT:-900}
export NGINX_DEFAULT_SERVER_NAME=${NGINX_DEFAULT_SERVER_NAME:-drupal}
envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME}' < /templates/default.conf > /etc/nginx/conf.d/default.conf
envsubst '${NGINX_PHP_READ_TIMEOUT}' < /templates/fastcgi.conf > /etc/nginx/fastcgi.conf
exec nginx -g "daemon off;"
