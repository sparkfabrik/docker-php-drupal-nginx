server {
    server_name ${DOMAIN_FROM};
    listen ${NGINX_DEFAULT_SERVER_PORT} ${DEFAULT_SERVER};
    return 301 $scheme://${DOMAIN_TO}$request_uri;
}
