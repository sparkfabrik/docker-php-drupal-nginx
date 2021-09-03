#!/bin/sh
set -e

function print {
  echo "${0}: ${@}"
}

export PHP_HOST=${PHP_HOST:-php}
export PHP_PORT=${PHP_PORT:-9000}
export NGINX_PHP_READ_TIMEOUT=${NGINX_PHP_READ_TIMEOUT:-900}

# If you use the rootless image the user directive is not needed
if [ $(id -u) -ne 0 ]; then
  sed -i '/^user /d' /etc/nginx/nginx.conf
  export NGINX_DEFAULT_SERVER_PORT=${NGINX_DEFAULT_SERVER_PORT:-8080}
else
  export NGINX_DEFAULT_SERVER_PORT=${NGINX_DEFAULT_SERVER_PORT:-80}
fi

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
  envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED}' < /templates/catch-all-server.conf > /etc/nginx/conf.d/catch-all-server.conf
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
export SITEMAP_URL=${SITEMAP_URL}

# Activate CORS on php location using a fragment.
export NGINX_CORS_ENABLED=${NGINX_CORS_ENABLED:-0}
export NGINX_CORS_DOMAINS=${NGINX_CORS_DOMAINS}
if [ ${NGINX_CORS_ENABLED} == 1 ]; then
  mkdir -p /etc/nginx/conf.d/fragments/location/cors
  if [ ! -z ${NGINX_CORS_DOMAINS} ]; then
    print "Activating filtered CORS on domains: ${NGINX_CORS_DOMAINS}"
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${DEFAULT_SERVER} ${NGINX_CORS_DOMAINS}' < /templates/fragments/location/cors/cors-filtered.conf > /etc/nginx/conf.d/fragments/location/cors/cors.conf
  else
    print "Activating unfiltered CORS"
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${DEFAULT_SERVER}' < /templates/fragments/location/cors/cors-unfiltered.conf > /etc/nginx/conf.d/fragments/location/cors/cors.conf
  fi
fi

if [ ${NGINX_HTTPSREDIRECT} == 1 ]; then
  print "Enabling HTTPS redirect"
  sed  -e '/#httpsredirec/r /templates/httpsredirect.conf' -i /templates/default.conf;
  sed  -e '/#httpsredirec/r /templates/httpsredirect.conf' -i /templates/subfolder.conf;
fi
if [ ${NGINX_GZIP_ENABLE} == 1 ]; then
  print "Enabling gzip"
  cp /templates/gzip.conf /etc/nginx/conf.d/gzip.conf
fi
envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${DEFAULT_SERVER}' < /templates/default.conf > /etc/nginx/conf.d/default.conf
if [ ${NGINX_SUBFOLDER} != 0 ]; then
  envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED}' < /templates/subfolder.conf > /etc/nginx/conf.d/default.conf
fi

# Handle robots.txt and sitemap directive
ROBOTS_PATH=${NGINX_DEFAULT_ROOT}/robots.txt
if [ -n "${SITEMAP_URL}" ] && [ -w "${ROBOTS_PATH}" ] ; then
  print "Handle robots.txt and sitemap directive"
	sed '/^Sitemap\:/d' ${ROBOTS_PATH} > ${ROBOTS_PATH}.sed; \
		mv ${ROBOTS_PATH}.sed ${ROBOTS_PATH}
	echo "Sitemap: ${SITEMAP_URL}" >> "${NGINX_DEFAULT_ROOT}/robots.txt"
fi

# Rewrite main server fragments.
print "Rewriting main server fragments on /etc/nginx/conf.d/fragments/*.conf"
for filename in /etc/nginx/conf.d/fragments/*.conf; do
  if [ -e "${filename}" ] ; then
    cp ${filename} ${filename}.tmp
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_OSB_BUCKET} ${NGINX_OSB_RESOLVER} ${DRUPAL_PUBLIC_FILES_PATH} ${NGINX_CACHE_CONTROL_HEADER}' < $filename.tmp > $filename
    rm ${filename}.tmp
  fi
done

# Rewrite custom server fragments.
print "Rewriting custom server fragments on /etc/nginx/conf.d/custom/*.conf"
for filename in /etc/nginx/conf.d/custom/*.conf; do
  if [ -e "${filename}" ] ; then
    cp ${filename} ${filename}.tmp
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_OSB_BUCKET} ${NGINX_OSB_RESOLVER} ${DRUPAL_PUBLIC_FILES_PATH} ${NGINX_CACHE_CONTROL_HEADER}' < $filename.tmp > $filename
    rm ${filename}.tmp
  fi
done

envsubst '${NGINX_PHP_READ_TIMEOUT}' < /templates/fastcgi.conf > /etc/nginx/fastcgi.conf
exec nginx -g "daemon off;"
