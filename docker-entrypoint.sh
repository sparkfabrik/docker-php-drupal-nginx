#!/bin/sh
# shellcheck disable=SC2002,SC3057,SC3060

set -e

print() {
  echo "${0}: ${*}"
}

export PHP_HOST="${PHP_HOST:-php}"
export PHP_PORT="${PHP_PORT:-9000}"
export NGINX_PHP_READ_TIMEOUT="${NGINX_PHP_READ_TIMEOUT:-900}"
export NGINX_CATCHALL_RETURN_CODE="${NGINX_CATCHALL_RETURN_CODE:-444}"

# If you use the rootless image the user directive is not needed
if [ "$(id -u)" -ne 0 ]; then
  sed -i '/^user /d' /etc/nginx/nginx.conf
  export NGINX_DEFAULT_SERVER_PORT="${NGINX_DEFAULT_SERVER_PORT:-8080}"
else
  export NGINX_DEFAULT_SERVER_PORT="${NGINX_DEFAULT_SERVER_PORT:-80}"
fi

# Activate HSTS header (default: off)
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security
# The suggested value for the max-age is 63072000 (2 years).
export NGINX_HSTS_MAX_AGE="${NGINX_HSTS_MAX_AGE:-0}"
export NGINX_HSTS_INCLUDE_SUBDOMAINS="${NGINX_HSTS_INCLUDE_SUBDOMAINS:-1}"
export NGINX_HSTS_PRELOAD="${NGINX_HSTS_PRELOAD:-1}"
if [ "${NGINX_HSTS_MAX_AGE}" -gt 0 ]; then
  export NGINX_HSTS_HEADER="max-age=${NGINX_HSTS_MAX_AGE}"
  if [ "${NGINX_HSTS_INCLUDE_SUBDOMAINS}" -eq 1 ]; then
    export NGINX_HSTS_HEADER="${NGINX_HSTS_HEADER}; includeSubDomains"
  fi
  if [ "${NGINX_HSTS_PRELOAD}" -eq 1 ]; then
    export NGINX_HSTS_HEADER="${NGINX_HSTS_HEADER}; preload"
  fi
  sed -e '/#hstsheader/r /templates/hsts.conf' -i /templates/default.conf;
  sed -e '/#hstsheader/r /templates/hsts.conf' -i /templates/subfolder.conf;
  sed -e '/#hstsheader/r /templates/hsts.conf' -i /templates/catch-all-server.conf;
  sed -e '/#hstsheader/r /templates/hsts.conf' -i /templates/from-to-www.conf.tpl;
fi

# If the variable NGINX_DEFAULT_SERVER_NAME is left empty
# (in this case the default value _ will be used), the default.conf
# server declaration will be declared as the default catch all server.
# Otherwise the default.conf server declaration will respond only
# to name servers defined in the NGINX_DEFAULT_SERVER_NAME env var
# and a catch all server retunrning 444 will be added.
export NGINX_DEFAULT_SERVER_NAME="${NGINX_DEFAULT_SERVER_NAME:-_}"
if [ "${NGINX_DEFAULT_SERVER_NAME}" = "_" ]; then
  export DEFAULT_SERVER="default_server"
else
  export DEFAULT_SERVER=""
  # shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
  envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_CATCHALL_RETURN_CODE} ${NGINX_HSTS_HEADER}' < /templates/catch-all-server.conf > /etc/nginx/conf.d/catch-all-server.conf
fi

export NGINX_DEFAULT_ROOT="${NGINX_DEFAULT_ROOT:-/var/www/html}"
export NGINX_HTTPSREDIRECT="${NGINX_HTTPSREDIRECT:-0}"
export NGINX_SUBFOLDER="${NGINX_SUBFOLDER:-0}"
# shellcheck disable=SC2155
export NGINX_SUBFOLDER_ESCAPED="$(echo "${NGINX_SUBFOLDER}" | sed 's/\//\\\//g')"
export NGINX_OSB_BUCKET="${NGINX_OSB_BUCKET}"
export NGINX_OSB_PUBLIC_PATH="${NGINX_OSB_PUBLIC_PATH:-}"
export NGINX_OSB_RESOLVER="${NGINX_OSB_RESOLVER:-8.8.8.8 ipv6=off}"
export HIDE_GOOGLE_GCS_HEADERS="${HIDE_GOOGLE_GCS_HEADERS:-1}"
export DRUPAL_PUBLIC_FILES_PATH="${DRUPAL_PUBLIC_FILES_PATH:-sites/default/files}"
export NGINX_CACHE_CONTROL_HEADER="${NGINX_CACHE_CONTROL_HEADER:-public,max-age=3600}"
export NGINX_GZIP_ENABLE="${NGINX_GZIP_ENABLE:-1}"
export SITEMAP_URL="${SITEMAP_URL}"
export NGINX_REDIRECT_FROM_TO_WWW="${NGINX_REDIRECT_FROM_TO_WWW:-0}"
export NGINX_HIDE_DRUPAL_HEADERS="${NGINX_HIDE_DRUPAL_HEADERS:-1}"
export NGINX_HIDE_SENSITIVE_HEADERS="${NGINX_HIDE_SENSITIVE_HEADERS:-1}"
export NGINX_XFRAME_OPTION_ENABLE="${NGINX_XFRAME_OPTION_ENABLE:-0}"
export NGINX_XFRAME_OPTION_VALUE="${NGINX_XFRAME_OPTION_VALUE:-SAMEORIGIN}"

# Custom nginx configuration.
export NGINX_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-200M}"

# Activate CORS on php location using a fragment.
export NGINX_CORS_ENABLED="${NGINX_CORS_ENABLED:-0}"
export NGINX_CORS_DOMAINS="${NGINX_CORS_DOMAINS}"
if [ "${NGINX_CORS_ENABLED}" = 1 ]; then
  mkdir -p /etc/nginx/conf.d/fragments/location/php
  if [ -n "${NGINX_CORS_DOMAINS}" ]; then
    print "Activating filtered CORS on domains: ${NGINX_CORS_DOMAINS}"
    # shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
    envsubst '${NGINX_CORS_DOMAINS}' < /templates/fragments/location/php/cors-filtered.conf > /etc/nginx/conf.d/fragments/location/php/cors.conf
  else
    print "Activating unfiltered CORS"
    cp /templates/fragments/location/php/cors-unfiltered.conf /etc/nginx/conf.d/fragments/location/php/cors.conf
  fi
fi

# If we are using an Object Storage Bucket, we add a custom location file.
# We also check if a file with the same name does not exist, to prevent the override.
if [ -n "${NGINX_OSB_BUCKET}" ] && [ ! -f "/etc/nginx/conf.d/fragments/001-osb-default.conf" ]; then
  mkdir -p /etc/nginx/conf.d/fragments
  # We add 001-osb-default.conf to fragments if Nginx is configured to use a bucket.
  # Env subst will be done later on all fragments files.
  cp /templates/fragments/001-osb-default.conf /etc/nginx/conf.d/fragments/001-osb-default.conf

  # If we want to activate the assets:// stream support over s3.
  if [ "${NGINX_ASSETS_STREAM_OVER_S3}" = 1 ]; then
    print "Enabling assets:// stream support"
    cp /templates/fragments/000-osb-lazy-assets-over-s3.conf /etc/nginx/conf.d/fragments/000-osb-lazy-assets-over-s3.conf
  fi

  # If we want cors, we need to add more config to osb location.
  if [ "${NGINX_CORS_ENABLED}" = 1 ]; then
    mkdir -p /etc/nginx/conf.d/fragments/location/osb
    if [ -n "${NGINX_CORS_DOMAINS}" ]; then
      print "Activating filtered OSB CORS on domains: ${NGINX_CORS_DOMAINS}"
      # shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
      envsubst '${NGINX_CACHE_CONTROL_HEADER} ${NGINX_CORS_DOMAINS}' < /templates/fragments/location/osb/cors-filtered.conf > /etc/nginx/conf.d/fragments/location/osb/cors.conf
    else
      print "Activating unfiltered OSB CORS"
      # shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
      envsubst '${NGINX_CACHE_CONTROL_HEADER}' < /templates/fragments/location/osb/cors-unfiltered.conf > /etc/nginx/conf.d/fragments/location/osb/cors.conf
    fi
  fi
  # If we want to suppress google headers coming from the google storage. 
  # We add more configuration on 001-osb-default.conf file template before adding it on fragments .
  if [ "${HIDE_GOOGLE_GCS_HEADERS}" = 1 ]; then
    print "Hiding Google Storage headers"
    sed -e '/#hidegoogleheaders/r /templates/fragments/location/osb/osb-hide-google-headers.conf' -i /etc/nginx/conf.d/fragments/001-osb-default.conf;
    if [ "${NGINX_ASSETS_STREAM_OVER_S3}" = 1 ]; then

      sed -e '/#hidegoogleheaders/r /templates/fragments/location/osb/osb-hide-google-headers.conf' -i /etc/nginx/conf.d/fragments/000-osb-lazy-assets-over-s3.conf;
    fi
  fi
fi

# If we want to enable X-Frame Options header to indicate whether or not a browser should be allowed 
# to render a page in a <frame>, <iframe>, <embed> or <object>
if [ "${NGINX_XFRAME_OPTION_ENABLE}" = 1 ]; then
  print "Enabling X-frame-Options Header"
  sed -e '/#securityheaders/r /templates/security-headers.conf' -i /templates/default.conf;
fi

if [ "${NGINX_HTTPSREDIRECT}" = 1 ]; then
  print "Enabling HTTPS redirect"
  sed -e '/#httpsredirec/r /templates/httpsredirect.conf' -i /templates/default.conf;
  sed -e '/#httpsredirec/r /templates/httpsredirect.conf' -i /templates/subfolder.conf;
fi

if [ "${NGINX_GZIP_ENABLE}" = 1 ]; then
  print "Enabling gzip"
  cp /templates/gzip.conf /etc/nginx/conf.d/gzip.conf
fi

# shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${DEFAULT_SERVER} ${NGINX_XFRAME_OPTION_VALUE} ${NGINX_HSTS_HEADER}' < /templates/default.conf > /etc/nginx/conf.d/default.conf

if [ "${NGINX_SUBFOLDER}" != 0 ]; then
  # shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
  envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_XFRAME_OPTION_VALUE} ${NGINX_HSTS_HEADER}' < /templates/subfolder.conf > /etc/nginx/conf.d/default.conf
fi

# Handle robots.txt and sitemap directive
ROBOTS_PATH=${NGINX_DEFAULT_ROOT}/robots.txt
if [ -n "${SITEMAP_URL}" ] && [ -w "${ROBOTS_PATH}" ] ; then
  print "Handle robots.txt and sitemap directive"
	sed '/^Sitemap\:/d' "${ROBOTS_PATH}" > "${ROBOTS_PATH}.sed"; \
		mv "${ROBOTS_PATH}.sed" "${ROBOTS_PATH}"
	echo "Sitemap: ${SITEMAP_URL}" >> "${NGINX_DEFAULT_ROOT}/robots.txt"
fi

sharp_replacement() {
  for filename in $1; do
  if [ -e "${filename}" ] ; then
    cp "${filename}" "${filename}.tmp"
    if [ "${NGINX_HSTS_MAX_AGE}" -gt 0 ]; then
      sed -e '/#hstsheader/r /templates/hsts.conf' -i "$filename.tmp";
    fi
    if [ "${NGINX_HTTPSREDIRECT}" = 1 ]; then
      print "Enabling HTTPS redirect"
      sed -e '/#httpsredirec/r /templates/httpsredirect.conf' -i "$filename.tmp";
    fi
    if [ "${NGINX_XFRAME_OPTION_ENABLE}" = 1 ]; then
      print "Enabling X-frame-Options Header"
      sed -e '/#securityheaders/r /templates/security-headers.conf' -i "$filename.tmp";
    fi
    # shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_OSB_BUCKET} ${NGINX_OSB_RESOLVER} ${DRUPAL_PUBLIC_FILES_PATH} ${NGINX_CACHE_CONTROL_HEADER} ${NGINX_CORS_DOMAINS} ${NGINX_HSTS_HEADER} ${NGINX_XFRAME_OPTION_ENABLE} ${NGINX_OSB_PUBLIC_PATH}' < "$filename.tmp" > "$filename"
    rm "${filename}.tmp"
  fi
done
}

# Rewrite main server fragments.
print "Rewriting main server fragments on /etc/nginx/conf.d/fragments/*.conf"
sharp_replacement "/etc/nginx/conf.d/fragments/*.conf"

# Rewrite custom server fragments.
print "Rewriting custom server fragments on /etc/nginx/conf.d/custom/*.conf"
sharp_replacement "/etc/nginx/conf.d/custom/*.conf"

# Check if an existing redirects.map file exists, otherwise we create an empty one.
if [ ! -e "/etc/nginx/conf.d/redirects.map" ] ; then
  touch "/etc/nginx/conf.d/redirects.map"
fi

# Rewrite root location fragments.
print "Rewriting root location fragments on /etc/nginx/conf.d/fragments/location/root/*.conf"
sharp_replacement "/etc/nginx/conf.d/fragments/location/root/*.conf"

# shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
envsubst '${NGINX_PHP_READ_TIMEOUT}' < /templates/fastcgi.conf > /etc/nginx/fastcgi.conf

# Hide the Drupal specific headers
if [ "${NGINX_HIDE_DRUPAL_HEADERS}" -eq 1 ]; then
  cat /templates/fastcgi-hide-drupal-headers.conf | tee -a /etc/nginx/fastcgi.conf >/dev/null
fi

# Hide the sensitive headers
SERVER_TOKEN_TOGGLE="on"
if [ "${NGINX_HIDE_SENSITIVE_HEADERS}" -eq 1 ]; then
  SERVER_TOKEN_TOGGLE="off"
  cat /templates/fastcgi-hide-sensitive-headers.conf | tee -a /etc/nginx/fastcgi.conf >/dev/null
fi
export SERVER_TOKEN_TOGGLE

# Process custom configuration
cp /etc/nginx/conf.d/000-custom.conf /etc/nginx/conf.d/000-custom.conf.tmp
# shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
envsubst '${SERVER_TOKEN_TOGGLE} ${NGINX_CLIENT_MAX_BODY_SIZE}' < /etc/nginx/conf.d/000-custom.conf.tmp > /etc/nginx/conf.d/000-custom.conf

# Hide project specific headers
if [ -r /templates/fastcgi-hide-additional-headers.conf ]; then
  cat /templates/fastcgi-hide-additional-headers.conf | tee -a /etc/nginx/fastcgi.conf >/dev/null
fi

# Process redirect from-to-www configuration
if [ "${NGINX_REDIRECT_FROM_TO_WWW}" -eq 1 ] && [ "${NGINX_DEFAULT_SERVER_NAME}" != "_" ]; then
  print "Enabling from-to-www redirects"
  touch /etc/nginx/conf.d/from-to-www.conf
  for domain in ${NGINX_DEFAULT_SERVER_NAME}; do
    if [ "${domain:0:4}" = "www." ]; then
      DOMAIN_FROM="${domain#www.}"
      DOMAIN_TO="${domain}"
    else
      DOMAIN_FROM="www.${domain}"
      DOMAIN_TO="${domain}"
    fi
    
    # Check if the related domain (<domain> without www or www.<domain>) is also valid as server name
    FOUND_RELATED=0
    echo "${NGINX_DEFAULT_SERVER_NAME}" | grep -E "(^|\s)${DOMAIN_FROM//./\\.}" >/dev/null || FOUND_RELATED=$?

    # If the related domain is present we need to avoid the redirect because it is a valid domain
    if [ ${FOUND_RELATED} -ne 0 ]; then
      print "/etc/nginx/conf.d/from-to-www.conf - Creating a redirect from ${DOMAIN_FROM} to ${DOMAIN_TO}"
      # shellcheck disable=SC2016 # The envsubst command needs to be executed without variable expansion
      DOMAIN_FROM=${DOMAIN_FROM} DOMAIN_TO=${DOMAIN_TO} \
        envsubst '${DOMAIN_FROM} ${DOMAIN_TO} ${NGINX_DEFAULT_SERVER_PORT} ${DEFAULT_SERVER} ${NGINX_HSTS_HEADER}' < /templates/from-to-www.conf.tpl \
        | tee -a /etc/nginx/conf.d/from-to-www.conf >/dev/null
    else
      print "/etc/nginx/conf.d/from-to-www.conf - Skipping redirect from ${DOMAIN_FROM} to ${DOMAIN_TO} because it already exists"
    fi
  done
fi

exec nginx -g "daemon off;"
