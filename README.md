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

Here you can find some reference documentation to fine tune Nginx and Drupal:

* https://www.nginx.com/resources/wiki/start/topics/recipes/drupal/
* https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/


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

* `PHP_HOST`: the php host (default: `php`)
* `PHP_PORT`: the php port (default: `9000`)
* `NGINX_PHP_READ_TIMEOUT`: the php timeout (default: `900`)
* `NGINX_DEFAULT_SERVER_NAME`: the server name (default: `_`)
* `NGINX_DEFAULT_ROOT`: the server root (default: `/var/www/html`)
* `NGINX_HTTPSREDIRECT`: enable/disable https redirect (default: `0`)
* `DECLARE_DEFAULT_SERVER`: if set to 1, we will explicitly declare the default.conf server declaration as the default_server.
* `NGINX_SUBFOLDER`: include nginx configuration files from subfolders (default: `0`)
* `NGINX_SUBFOLDER_ESCAPED`: (default: `0`)
* `NGINX_OSB_BUCKET`: needed when using drupal+s3fs, contains the remote bucket url to proxy aggregated ccs/js relative urls
* `NGINX_OSB_RESOLVER`: needed when using drupal+s3fs, contains the host resolver that nginx uses to resolve the remote bucket url (default: `8.8.8.8`)
* `DRUPAL_PUBLIC_FILES_PATH`: the path for Drupal's public files (default: `sites/default/files`)
* `NGINX_CACHE_CONTROL_HEADER`: caching policy for public files (default: `public,max-age=3600`)
