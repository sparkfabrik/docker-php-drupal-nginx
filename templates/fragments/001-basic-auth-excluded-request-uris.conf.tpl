if ($request_uri ~ ^(${NGINX_BASIC_AUTH_EXCLUDE_REQUEST_URIS})) {
  set $realm off;
}
