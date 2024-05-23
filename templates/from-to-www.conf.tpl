server {
    access_log /var/log/nginx/access.log ${NGINX_ACCESS_LOG_FORMAT};

    server_name ${DOMAIN_FROM};
    listen ${NGINX_DEFAULT_SERVER_PORT} ${DEFAULT_SERVER};

    #hstsheader
    #httpsredirect

    set $request_proto $scheme;
    if ($http_x_forwarded_proto = "https") {
        set $request_proto "https";
    }
    return 301 $request_proto://${DOMAIN_TO}$request_uri;
}
