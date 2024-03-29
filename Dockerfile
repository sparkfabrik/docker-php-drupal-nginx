ARG NGINX_IMAGE_TAG=1.25.3-alpine-slim

FROM nginx:${NGINX_IMAGE_TAG}

# Pass inexistent UUID (e.g.: 1001) to enhance the container security
ARG user=root

LABEL org.opencontainers.image.source https://github.com/sparkfabrik/docker-php-drupal-nginx/tree/feature/d8

# Add for backward compatibility.
ENV NGINX_ACCESS_LOG_FORMAT=main

# Install packages
RUN apk add --no-cache apache2-utils

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY templates /templates
COPY config/conf.d /etc/nginx/conf.d

RUN chmod +x /docker-entrypoint.sh && \
    chmod 775 /etc/nginx && \
    chmod 775 /etc/nginx/conf.d && \
    find /etc/nginx/conf.d -type f -exec chmod 664 {} + && \
    mkdir -p /etc/nginx/conf.d/custom && \
    chmod 775 /etc/nginx/conf.d/custom && \
    mkdir -p /etc/nginx/conf.d/fragments && \
    chmod 775 /etc/nginx/conf.d/fragments && \
    chgrp root /var/cache/nginx && \
    chmod 775 /var/cache/nginx && \
    chmod 775 /var/log/nginx && \
    mkdir -p /var/run/nginx && \
    chmod 775 /var/run/nginx && \
    sed -i 's|/var/run/nginx.pid|/var/run/nginx/nginx.pid|g' /etc/nginx/nginx.conf && \
    find /templates -type d -exec chmod 775 {} + && \
    chmod 664 /etc/nginx/fastcgi.conf && \
    chmod 664 /etc/nginx/conf.d/default.conf

# Go to target user
USER $user

ENTRYPOINT [ "/docker-entrypoint.sh" ]
