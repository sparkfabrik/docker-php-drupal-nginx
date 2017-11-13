#!/bin/sh
export PHP_HOST=${PHP_HOST:-php}
export PHP_PORT=${PHP_PORT:-9000}
export NGINX_PHP_READ_TIMEOUT=${NGINX_PHP_READ_TIMEOUT:-900}
envsubst '${PHP_HOST} ${PHP_PORT}' < /templates/default.conf > /etc/nginx/conf.d/default.conf
envsubst '${NGINX_PHP_READ_TIMEOUT}' < /templates/fastcgi.conf > /etc/nginx/fastcgi.conf
exec nginx -g "daemon off;"
