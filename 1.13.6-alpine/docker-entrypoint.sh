#!/bin/sh
export PHP_HOST=${PHP_HOST:-php}
export PHP_PORT=${PHP_PORT:-9000}
export NGINX_PHP_READ_TIMEOUT=${NGINX_PHP_READ_TIMEOUT:-900}
export NGINX_DEFAULT_SERVER_NAME=${NGINX_DEFAULT_SERVER_NAME:-drupal}
export NGINX_DEFAULT_ROOT=${NGINX_DEFAULT_ROOT:-/var/www/html}
export NGINX_HTTPSREDIRECT=${NGINX_HTTPSREDIRECT:-0}
export NGINX_SUBFOLDER=${NGINX_SUBFOLDER:-0}
if [ $NGINX_HTTPSREDIRECT == 1 ]; then
  sed  -e '/#httpsredirec/r /templates/httpsredirect.conf' -i /templates/default.conf;
fi
envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT}' < /templates/default.conf > /etc/nginx/conf.d/default.conf
if [ $NGINX_SUBFOLDER != 0 ]; then
  envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER}' < /templates/subfolder.conf > /etc/nginx/conf.d/default.conf
fi
envsubst '${NGINX_PHP_READ_TIMEOUT}' < /templates/fastcgi.conf > /etc/nginx/fastcgi.conf
exec nginx -g "daemon off;"
