#!/bin/sh
export PHP_HOST=${PHP_HOST:-php}
export PHP_PORT=${PHP_PORT:-9000}
export NGINX_PHP_READ_TIMEOUT=${NGINX_PHP_READ_TIMEOUT:-900}
export NGINX_DEFAULT_SERVER_NAME=${NGINX_DEFAULT_SERVER_NAME:-drupal}
export NGINX_DEFAULT_ROOT=${NGINX_DEFAULT_ROOT:-/var/www/html}
export NGINX_HTTPSREDIRECT=${NGINX_HTTPSREDIRECT:-0}
export NGINX_SUBFOLDER=${NGINX_SUBFOLDER:-0}
export NGINX_SUBFOLDER_ESCAPED=$(echo ${NGINX_SUBFOLDER} | sed 's/\//\\\//g')
export NGINX_OSB_BUCKET=${NGINX_OSB_BUCKET}
export NGINX_OSB_RESOLVER=${NGINX_OSB_RESOLVER:-8.8.8.8}
export DRUPAL_PUBLIC_FILES_PATH=${DRUPAL_PUBLIC_FILES_PATH:-sites/default/files}
export NGINX_CACHE_CONTROL_HEADER=${NGINX_CACHE_CONTROL_HEADER:-public,max-age=3600}
if [ $NGINX_HTTPSREDIRECT == 1 ]; then
  sed  -e '/#httpsredirec/r /templates/httpsredirect.conf' -i /templates/default.conf;
  sed  -e '/#httpsredirec/r /templates/httpsredirect.conf' -i /templates/subfolder.conf;
fi
envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT}' < /templates/default.conf > /etc/nginx/conf.d/default.conf
if [ $NGINX_SUBFOLDER != 0 ]; then
  envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED}' < /templates/subfolder.conf > /etc/nginx/conf.d/default.conf
fi

# Rewrite fragments.
for filename in /etc/nginx/conf.d/fragments/*.conf; do
  if [ -e "${filename}" ] ; then
    cp ${filename} ${filename}.tmp
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_OSB_BUCKET} ${NGINX_OSB_RESOLVER} ${DRUPAL_PUBLIC_FILES_PATH} ${NGINX_CACHE_CONTROL_HEADER}' < $filename.tmp > $filename
    rm ${filename}.tmp
  fi
done

# Attempt to create the redirects files if not present.
touch /etc/nginx/conf.d/redirects.map

envsubst '${NGINX_PHP_READ_TIMEOUT}' < /templates/fastcgi.conf > /etc/nginx/fastcgi.conf
exec nginx -g "daemon off;"
