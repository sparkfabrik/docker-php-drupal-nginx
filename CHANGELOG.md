# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- New `1.30.2-alpine-slim` nginx base image, which is now the default and the
  source of the rolling `:d8` / `:d8-rootless` tags. Earlier `alpine-slim`
  versions (`1.25.1`, `1.25.3`, `1.25.5`, `1.26.0`) are also published.
- Basic authentication support through the `NGINX_BASIC_AUTH_USER`,
  `NGINX_BASIC_AUTH_PASS`, `NGINX_BASIC_AUTH_REALM` and `NGINX_BASIC_AUTH_FILE`
  environment variables, with `NGINX_BASIC_AUTH_EXCLUDE_LOCATIONS` and
  `NGINX_BASIC_AUTH_EXCLUDE_REQUEST_URIS` to exempt specific paths (for example
  a health-check probe). `OPTIONS` requests are never challenged.
- CORS support through `NGINX_CORS_ENABLED`, with optional `NGINX_CORS_DOMAINS`
  to restrict CORS to a list of allowed origins.
- Forbidden locations that deny access to `composer.json`/`composer.lock` and
  `package.json`/`package-lock.json`, with a configurable response code via
  `NGINX_FORBIDDEN_LOCATIONS_EXIT_CODE`. They are activated automatically when
  `ENV` is not local.
- `Content-Security-Policy` header support through the `NGINX_CSP_HEADER`
  environment variable.
- Object storage (s3fs) asset streaming and the lazy assets aggregator
  introduced in Drupal 10.1, through `NGINX_ASSETS_STREAM_OVER_S3`,
  `NGINX_OSB_ASSETS_PATH` and `DRUPAL_ASSETS_FILES_PATH`.
- `NGINX_OSB_RESOLVER_ENFORCE_IPV6_OFF` to enforce `ipv6=off` on the object
  storage resolver.
- HTTPS redirect support through `NGINX_HTTPSREDIRECT`, honouring the original
  protocol from the `X-Forwarded-Proto` header.
- Configurable request body size through `NGINX_CLIENT_MAX_BODY_SIZE`
  (default `200M`).
- Configurable gzip compression through `NGINX_GZIP_ENABLE`.
- Configurable catch-all server return code through `NGINX_CATCHALL_RETURN_CODE`.
- `DRUPAL_PUBLIC_FILES_PATH` and `NGINX_CACHE_CONTROL_HEADER` to control the
  public files location and its caching policy.
- The forwarded `User-Agent` is now passed to PHP-FPM in the fastcgi parameters.
- The `robots.txt` route can be overridden by PHP code.
- Rootless image flavour, published with the `-rootless` tag suffix.

### Changed

- The default base image is now `1.30.2-alpine-slim`; nginx versions older than
  `1.25.1` are no longer built.
- Structured logging is configured across all server definitions, and the log
  format includes the `X-Forwarded-For` value.
- The CI workflow was modernized: GitHub Actions were upgraded, the QEMU
  emulated build was replaced with native `amd64` and `arm64` runners that push
  per-architecture digests merged into a final manifest, the version list is
  sourced from a single `NGINX_TAGS` variable, GitHub Actions layer caching was
  added, and the workflow declares least-privilege `permissions`.

### Fixed

- Rootless image failing to start because newer nginx base images moved the pid
  directive to `/run/nginx.pid`; the pid rewrite now matches it regardless of
  path.
- The rolling `:d8` / `:d8-rootless` tags, which were gated on a base version
  absent from the build matrix and therefore never published.

### Security

- Restored a restrictive `.well-known` handling that serves only `.txt` files
  and denies PHP execution, preventing source code leakage.

---

The dated sections below were not maintained for a long period. They are kept
for historical reference; all changes made since are collected under the
`[Unreleased]` section above.

## 2022-12-14

### Added

- Added the ability to enable HSTS in custom server fragments configurations, to enable it you will need to add in the server definition the `#hstsheader` annotation

## 2022-12-12

### Added

- Added HSTS header in the server definition `catch-all-server.conf` and `from-to-www.conf`, if enabled it will automatically add the header in the following servers:

  - default.conf
  - subfolder.conf
  - catch-all-server.conf
  - from-to-www.conf

## 2022-09-19

### Added

- Add the support in the `redirects.map` file to use `$host$request_uri` as key (left-side) to manage multiple domains on the same nginx instance.
- Add the new `1.23.1-alpine` image.

## 2022-05-03

### Added

- New `NGINX_HSTS_MAX_AGE`, `NGINX_HSTS_INCLUDE_SUBDOMAINS`, `NGINX_HSTS_PRELOAD` environment variables to control the `Strict-Transport-Security` header. By default the HSTS header is disabled.

## 2022-04-28

### Changed

- The `NGINX_HIDE_DRUPAL_HEADERS` environment variable to hide the drupal information from the response headers is active by default.

## 2022-04-27

### Added

- New Nginx `1.21.6` version available.

## 2021-10-25

### Added

- New `NGINX_HIDE_DRUPAL_HEADERS` environment variable to hide the drupal information from the response headers (default: the headers are visible)
- New `NGINX_HIDE_SENSITIVE_HEADERS` environment variable to hide all the sensitive information from the response headers (default: the headers will be removed)

## 2022-02-03

### Added

- New `HIDE_GOOGLE_GCS_HEADERS` environment variable to hide the google response headers coming from the google object storage bucket (default: the headers are hidden)

## 2022-04-12

### Added

- New `NGINX_XFRAME_OPTION_ENABLE` environment variable to enable X-Frame Options header to indicate whether or not a browser should be allowed to render a page in a frame, iframe, embed, object (default: the header is enabled with "SAMEORIGIN" value)

- New `NGINX_XFRAME_OPTION_VALUE` environment variable to assign a specific value to the X-Frame Options header . Possible values: SAMEORIGIN , DENY. Default: SAMEORIGIN
