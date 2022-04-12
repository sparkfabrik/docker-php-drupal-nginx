# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2021-10-25

### Added

- New `NGINX_HIDE_DRUPAL_HEADERS` environment variable to hide the drupal information from the response headers (default: the headers are visible)
- New `NGINX_HIDE_SENSITIVE_HEADERS` environment variable to hide all the sensitive information from the response headers (default: the headers will be removed)

## 2022-02-03

### Added

- New `HIDE_GOOGLE_GCS_HEADERS` environment variable to hide the google response headers coming from the google object storage bucket (default: the headers are hidden)

# 2022-04-12

### Added

- New `NGINX_XFRAME_OPTION_ENABLE` environment variable to enable X-Frame Options header to indicate whether or not a browser should be allowed to render a page in a frame, iframe, embed, object (default: the header is enabled with "SAMEORIGIN" value)
