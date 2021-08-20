# Docker PHP NGINX

This docker image is designed to run PHP applications, with some
specific configuration for Drupal 8.

## Customizations

NGINX is configured dynamically by generating a `default.conf file.

```
envsubst '${PHP_HOST} ${PHP_PORT} ${NGINX_DEFAULT_SERVER_NAME} ${NGINX_DEFAULT_ROOT} ${DEFAULT_SERVER}' < /templates/default.conf > /etc/nginx/conf.d/default.conf
```

If you want customize the default configuration file, just override the file `/templates/default.conf`.

There is just one `server` configuration, which acts basically like a placeholder, you can customize it
by mounting extra configurations under `/etc/nginx/conf.d/fragments`, the files are then parsed by
substituting the env variables with the actual values.

Here you can find some reference documentation to fine tune Nginx:

- https://www.nginx.com/resources/wiki/start/topics/recipes/drupal/
- https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/
- http://nginx.org/en/docs/http/server_names.html#optimization

### Default server custom configurations fragments

```
# Rewrite main server fragments.
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

```
# Rewrite custom server fragments.
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
- `NGINX_DEFAULT_SERVER_NAME`: the server name (default: `_`)
- `NGINX_DEFAULT_ROOT`: the server root (default: `/var/www/html`)
- `NGINX_HTTPSREDIRECT`: enable/disable https redirect (default: `0`)
- `NGINX_SUBFOLDER`: include nginx configuration files from subfolders (default: `0`)
- `NGINX_SUBFOLDER_ESCAPED`: (default: `0`)
- `NGINX_OSB_BUCKET`: needed when using drupal+s3fs, contains the remote bucket url to proxy aggregated ccs/js relative urls
- `NGINX_OSB_RESOLVER`: needed when using drupal+s3fs, contains the host resolver that nginx uses to resolve the remote bucket url (default: `8.8.8.8`)
- `DRUPAL_PUBLIC_FILES_PATH`: the path for Drupal's public files (default: `sites/default/files`)
- `NGINX_CACHE_CONTROL_HEADER`: caching policy for public files (default: `public,max-age=3600`)
- `NGINX_GZIP_ENABLE`: enable the gzip compression (default: `1`)
- `SITEMAP_URL`: the absolute URL of the website sitemap that should be written on _robots.txt_ file for SEO purposes (no default provided, the directive is added to the _robots.txt_ only when the variable exists)
- `NGINX_CORS_ENABLED_DOMAINS`: a list of CORS enabled domains (no default provided)

## Rootless feature

You can use `build-arg` to specify a `user` argument different from `root` to build the image with this feature.
If you provide a non-root user the container will drop its privileges targeting the specified user.
We have inserted the specific make targets with dedicated image suffix tags (`-rootless`) for these flavours.

You can find some more information [here](https://docs.bitnami.com/tutorials/work-with-non-root-containers/).
