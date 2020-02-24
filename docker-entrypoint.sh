#!/bin/sh
set -e
export PHP_HOST=${PHP_HOST:-php}
export PHP_PORT=${PHP_PORT:-9000}
export NGINX_PHP_READ_TIMEOUT=${NGINX_PHP_READ_TIMEOUT:-900}
# If the variable NGINX_DEFAULT_SERVER_NAME is left empty
# (in this case the default value _ will be used), the default.conf
# server declaration will be declared as the default catch all server.
# Otherwise the default.conf server declaration will respond only
# to name servers defined in the NGINX_DEFAULT_SERVER_NAME env var
# and a catch all server retunrning 444 will be added.
export NGINX_DEFAULT_SERVER_NAME=${NGINX_DEFAULT_SERVER_NAME:-_}
if [ $NGINX_DEFAULT_SERVER_NAME == "_" ]; then
  export DEFAULT_SERVER="default_server"
else
  export DEFAULT_SERVER=""
  cp /templates/catch-all-server.conf /etc/nginx/conf.d/catch-all-server.conf
fi
export NGINX_DEFAULT_ROOT=${NGINX_DEFAULT_ROOT:-/var/www/html}
export NGINX_HTTPSREDIRECT=${NGINX_HTTPSREDIRECT:-0}
export NGINX_SUBFOLDER=${NGINX_SUBFOLDER:-0}
export NGINX_SUBFOLDER_ESCAPED=$(echo ${NGINX_SUBFOLDER} | sed 's/\//\\\//g')
export NGINX_OSB_BUCKET=${NGINX_OSB_BUCKET}
export NGINX_OSB_RESOLVER=${NGINX_OSB_RESOLVER:-8.8.8.8}
export DRUPAL_PUBLIC_FILES_PATH=${DRUPAL_PUBLIC_FILES_PATH:-sites/default/files}
export NGINX_CACHE_CONTROL_HEADER=${NGINX_CACHE_CONTROL_HEADER:-public,max-age=3600}
export NGINX_GZIP_ENABLE=${NGINX_GZIP_ENABLE:-1}
if [ ${NGINX_HTTPSREDIRECT} == 1 ]; then
  sed  -e '/#httpsredirec/r /templates/httpsredirect.conf' -i /templates/default.conf;
  sed  -e '/#httpsredirec/r /templates/httpsredirect.conf' -i /templates/subfolder.conf;
fi
if [ ${NGINX_GZIP_ENABLE} == 1 ]; then
  cp /templates/gzip.conf /etc/nginx/conf.d/gzip.conf
fi
envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${DEFAULT_SERVER}' < /templates/default.conf > /etc/nginx/conf.d/default.conf
if [ ${NGINX_SUBFOLDER} != 0 ]; then
  envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED}' < /templates/subfolder.conf > /etc/nginx/conf.d/default.conf
fi

# Rewrite main server fragments.
for filename in /etc/nginx/conf.d/fragments/*.conf; do
  if [ -e "${filename}" ] ; then
    cp ${filename} ${filename}.tmp
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_OSB_BUCKET} ${NGINX_OSB_RESOLVER} ${DRUPAL_PUBLIC_FILES_PATH} ${NGINX_CACHE_CONTROL_HEADER}' < $filename.tmp > $filename
    rm ${filename}.tmp
  fi
done

# Rewrite custom server fragments.
for filename in /etc/nginx/conf.d/custom/*.conf; do
  if [ -e "${filename}" ] ; then
    cp ${filename} ${filename}.tmp
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_OSB_BUCKET} ${NGINX_OSB_RESOLVER} ${DRUPAL_PUBLIC_FILES_PATH} ${NGINX_CACHE_CONTROL_HEADER}' < $filename.tmp > $filename
    rm ${filename}.tmp
  fi
done

envsubst '${NGINX_PHP_READ_TIMEOUT}' < /templates/fastcgi.conf > /etc/nginx/fastcgi.conf
exec nginx -g "daemon off;"
