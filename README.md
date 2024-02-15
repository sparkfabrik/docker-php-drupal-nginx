# Docker PHP NGINX

This docker image is designed to run PHP applications, with some
specific configuration for Drupal 8.

## Customizations

NGINX is configured dynamically by generating a `default.conf file.

```bash
envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${DEFAULT_SERVER}' < /templates/default.conf > /etc/nginx/conf.d/default.conf

```

If you want customize the default configuration file, just override the file `/templates/default.conf`.

There is just one `server` configuration, which acts basically like a placeholder, you can customize it
by mounting extra configurations under `/etc/nginx/conf.d/fragments`, the files are then parsed by
substituting the env variables with the actual values.

Here you can find some reference documentation to fine tune Nginx:

- <https://www.nginx.com/resources/wiki/start/topics/recipes/drupal/>
- <https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/>
- <http://nginx.org/en/docs/http/server_names.html#optimization>

### Default server custom configurations fragments

```bash

# Rewrite main server fragments

for filename in /etc/nginx/conf.d/fragments/*.conf; do
  if [ -e "${filename}" ] ; then
    cp ${filename} ${filename}.tmp
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_OSB_BUCKET} ${NGINX_OSB_RESOLVER} ${DRUPAL_PUBLIC_FILES_PATH} ${NGINX_CACHE_CONTROL_HEADER}' < $filename.tmp > $filename
    rm ${filename}.tmp
  fi
done

```

### Extra configurations

You can also mount extra configurations (eg: a new server configuration), by placing files to: `/etc/nginx/conf.d/custom`, as
the default server fragments, also this file get parsed by the entrypoint to substitute the env files.

```bash

# Rewrite custom server fragments

for filename in /etc/nginx/conf.d/custom/*.conf; do
  if [ -e "${filename}" ] ; then
    cp ${filename} ${filename}.tmp
    envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${NGINX_SUBFOLDER} ${NGINX_SUBFOLDER_ESCAPED} ${NGINX_OSB_BUCKET} ${NGINX_OSB_RESOLVER} ${DRUPAL_PUBLIC_FILES_PATH} ${NGINX_CACHE_CONTROL_HEADER}' < $filename.tmp > $filename
    rm ${filename}.tmp
  fi
done

```

## Env variables

The entrypoint file contains a list of environment variables that will be replaced in all nginx configuration files.

- `PHP_HOST`: the php host (default: `php`)
- `PHP_PORT`: the php port (default: `9000`)
- `NGINX_PHP_READ_TIMEOUT`: the php timeout (default: `900`)
- `NGINX_CATCHALL_RETURN_CODE`: the catchall server return code (default: `444`)
- `NGINX_DEFAULT_SERVER_NAME`: the server name (default: `_`)
- `NGINX_DEFAULT_SERVER_PORT`: the server port (default: `80` if user is root, `8080` otherwise)
- `NGINX_BASIC_AUTH_USER`: the basic auth user (default: `admin`)
- `NGINX_BASIC_AUTH_PASS`: the basic auth password (default: ``)
- `NGINX_BASIC_AUTH_REALM`: the basic auth realm, used as title for the login prompt (default: `Authentication Required - Sparkfabrik`)
- `NGINX_BASIC_AUTH_FILE`: the basic auth file (default: `/etc/nginx/conf.d/fragments/.htpasswd`)
- `NGINX_BASIC_AUTH_EXCLUDE_LOCATIONS`: the basic auth exclude locations as comma separated list (default: ``)
- `NGINX_BASIC_AUTH_EXCLUDE_REQUEST_URIS`: the basic auth exclude request uris as pipe or comma separated list; if you are deploying this container with a probe, you should exclude the probe path from the basic auth (default: ``)
- `NGINX_HSTS_MAX_AGE`: enables the `Strict-Transport-Security` header and defines the `max-age` value (default: 0)
- `NGINX_HSTS_INCLUDE_SUBDOMAINS`: enables the `includeSubDomains` feature in the `Strict-Transport-Security` header (default: 1)
- `NGINX_HSTS_PRELOAD`: enables the `preload` feature in the `Strict-Transport-Security` header (default: 1)
- `NGINX_CSP_HEADER`: enables the `Content-Security-Policy` header and defines the value (default: the header is not set)
- `NGINX_ACCESS_LOG_FORMAT`: the access log format; the two available options are `main` and `structured`. (default: `structured` if the `ENV` != `loc`, `main` otherwise)
- `NGINX_DEFAULT_ROOT`: the server root (default: `/var/www/html`)
- `NGINX_HTTPSREDIRECT`: enable/disable https redirect (default: `0`)
- `NGINX_SUBFOLDER`: include nginx configuration files from subfolders (default: `0`)
- `NGINX_SUBFOLDER_ESCAPED`: (default: `0`)
- `NGINX_OSB_BUCKET`: needed when using drupal+s3fs, contains the remote bucket url to proxy the asset relative urls
- `NGINX_OSB_PUBLIC_PATH`: defines the public path for the assets in the bucket
- `NGINX_OSB_ASSETS_PATH`: defines the assets path in the bucket; it is used for the lazy loading of the assets starting from drupal `10.1`
- `NGINX_ASSETS_STREAM_OVER_S3`: enables the lazy loading of the assets from the bucket (default: `0`)
- `NGINX_OSB_RESOLVER`: needed when using drupal+s3fs, contains the host resolver that nginx uses to resolve the remote bucket url (default: `8.8.8.8 ipv6=off`)
- `NGINX_OSB_RESOLVER_ENFORCE_IPV6_OFF`: is used to enforce the ipv6 off for the resolver; if the ipv6 resolution is already disabled, it takes no effect (default: `1`)
- `HIDE_GOOGLE_GCS_HEADERS`: hides google response headers coming from the GCS object storage bucket (default: the headers are hidden)
- `DRUPAL_PUBLIC_FILES_PATH`: the path for Drupal's public files (default: `sites/default/files`)
- `DRUPAL_ASSETS_FILES_PATH`: the path for Drupal's assets files; it is used for the lazy loading of the assets starting from drupal `10.1` (default: `sites/default/files`)
- `NGINX_CACHE_CONTROL_HEADER`: caching policy for public files (default: `public,max-age=3600`)
- `NGINX_GZIP_ENABLE`: enable the gzip compression (default: `1`)
- `SITEMAP_URL`: the absolute URL of the website sitemap that should be written on _robots.txt_ file for SEO purposes (no default provided, the directive is added to the _robots.txt_ only when the variable exists)
- `NGINX_REDIRECT_FROM_TO_WWW`: enables the redirect from `www` to the domain without `www` and vice-versa (default: `0`)
- `NGINX_HIDE_DRUPAL_HEADERS`: hide the drupal information from the response headers (default: the headers are visible)
- `NGINX_HIDE_SENSITIVE_HEADERS`: hide all the sensitive information from the response headers (default: the headers will be removed)
- `NGINX_XFRAME_OPTION_ENABLE`: enables the `X-Frame-Options` header (default: `0`)
- `NGINX_XFRAME_OPTION_VALUE`: the value of the `X-Frame-Options` header; if the `NGINX_XFRAME_OPTION_ENABLE` is set to `0`, the header will not be set (default: `SAMEORIGIN`)
- `NGINX_CLIENT_MAX_BODY_SIZE`: the maximum allowed size for the client request body (default: `200M`)
- `NGINX_CORS_ENABLED`: enable cors for `/` path and the caller origin header represented by `$http_origin` nginx variable (<https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Origin>) (default: `0`)
- `NGINX_CORS_DOMAINS`: a list of CORS enabled domains to activate cors just for the specified ones (no default provided)

## Rootless feature

You can use `build-arg` to specify a `user` argument different from `root` to build the image with this feature.
If you provide a non-root user the container will drop its privileges targeting the specified user.
We have inserted the specific make targets with dedicated image suffix tags (`-rootless`) for these flavours.

You can find some more information [here](https://docs.bitnami.com/tutorials/work-with-non-root-containers/).

## redirects.map file

You can use the file `/etc/nginx/conf.d/redirects.map` to specify the static redirection that you want to manage. Each line of the file represents a key-value pair used to verify the current request and to send the 301 header and the corresponding new `Location` to the client. The file structure is:

```bash
<key to match> <new localtion>;
```

The key to match, or the left side of the file, could be the host and path (e.g.: `www.example.com/my-awesome-path`) or only the path (e.g.: `/my-awesome-path`). In the case of the same path, the more detailed rule will be applied (host and path), **ignoring the order in the file**. **ATTENTION**: as described, the left part of the file is treated as a key, so you must avoid any conflict.

### Example

Here you can find an example for the `redirects.map` file:

```bash
# The line below will send a redirect only for .com TLD to a new path
www.example.com/my-awesome-path https://www.example.com/my-new-awesome-path;
# The line below will send a redirect only for .co.uk TLD to a new path
www.example.co.uk/my-awesome-path https://www.example.co.uk/my-new-awesome-path;
# The line below will send a redirect for all other domains to the .it TLD and to a new path
/my-awesome-path https://www.example.it/another-awesome-path;
# The line below will send a redirect only for .fr TLD to a new path
www.example.fr/my-awesome-path https://www.example.fr/my-new-awesome-path;
```

With this configuration, the nginx server will first test the host and path key, and if there is no match it will then also test the simple path. You can find some examples of response header below, obtained when using the previous `redirects.map` file:

```bash
$ curl --head -H "Host: www.example.com" http://localhost/my-awesome-path
HTTP/1.1 301 Moved Permanently
Location: https://www.example.com/my-new-awesome-path
```

```bash
$ curl --head -H "Host: www.example.co.uk" http://localhost/my-awesome-path
HTTP/1.1 301 Moved Permanently
Location: https://www.example.co.uk/my-new-awesome-path
```

```bash
$ curl --head -H "Host: www.example.eu" http://localhost/my-awesome-path
HTTP/1.1 301 Moved Permanently
Location: https://www.example.it/another-awesome-path
```

```bash
$ curl --head -H "Host: www.example.fr" http://localhost/my-awesome-path
HTTP/1.1 301 Moved Permanently
Location: https://www.example.fr/my-new-awesome-path
```

```bash
$ curl --head -H "Host: www.example.de" http://localhost/my-awesome-path
HTTP/1.1 301 Moved Permanently
Location: https://www.example.it/another-awesome-path
```

You can find the redirects.map test file in the `example` folder of this repo.
