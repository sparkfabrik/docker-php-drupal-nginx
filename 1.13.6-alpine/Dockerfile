FROM nginx:1.13.6-alpine

LABEL org.opencontainers.image.source https://github.com/sparkfabrik/docker-php-drupal-nginx/tree/master

COPY templates /templates

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]
