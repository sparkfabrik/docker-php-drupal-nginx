# docker-php-nginx
Docker NGINX php container

## env variables

The entrypoint file contains a list of environment variables that will be replaced in all nginx configuration files.

* `PHP_HOST`: the php host (default: `php`)
* `PHP_PORT`: the php port (default: `9000`)
* `NGINX_PHP_READ_TIMEOUT`: the php timeout (default: `900`)
* `NGINX_DEFAULT_SERVER_NAME`: the server name (default: `drupal`)
* `NGINX_DEFAULT_ROOT`: the server root (default: `/var/www/html`)
* `NGINX_HTTPSREDIRECT`: enable/disable https redirect (default: `0`)
* `NGINX_SUBFOLDER`: include nginx configuration files from subfolders (default: `0`)
* `NGINX_SUBFOLDER_ESCAPED`: (default: `0`)
* `NGINX_OSB_BUCKET`: needed when using drupal+s3fs, contains the remote bucket url to proxy aggregated ccs/js relative urls
* `NGINX_OSB_RESOLVER`: needed when using drupal+s3fs, contains the host resolver that nginx uses to resolve the remote bucket url (default: `8.8.8.8`)
* `DRUPAL_PUBLIC_FILES_PATH`: the path for Drupal's public files (default: `sites/default/files`)
