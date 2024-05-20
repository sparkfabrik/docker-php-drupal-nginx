server {
    server_name ${DOMAIN_FROM};
    listen ${NGINX_DEFAULT_SERVER_PORT} ${DEFAULT_SERVER};
    #hstsheader
    set $current_proto $scheme;
    if ($http_x_forwarded_proto = "https") {
        set $current_proto "https";
    }
    return 301 $current_proto://${DOMAIN_TO}$request_uri;
}
