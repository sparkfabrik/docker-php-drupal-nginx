# AGENTS.md

Instructions for coding agents working on this repository. Complements
`README.md` with agent-specific technical guidance.

## Project Overview

This repository builds the `docker-php-drupal-nginx` Docker image: an nginx
front-end for PHP/Drupal 8+ applications. The image ships a single placeholder
`server` configuration that is rendered at container start, plus a set of
opt-in features (basic auth, CORS, HSTS, CSP, structured logging, object-storage
asset proxying, forbidden locations, redirects) toggled through environment
variables.

There is no application code here — the deliverable is the image itself.

**Tech stack:** nginx (alpine-slim base), POSIX shell (entrypoint + tests),
`envsubst` templating, Docker Buildx, GitHub Actions.

### Architecture

- `Dockerfile` — builds the image from a parametrised `nginx:${NGINX_IMAGE_TAG}`
  base. The `user` build-arg (`root` or `1001`) selects the flavour.
- `docker-entrypoint.sh` — reads environment variables, renders the templates
  with `envsubst`, and assembles the final nginx configuration.
- `templates/` — nginx config templates and fragments rendered by the entrypoint.
- `config/conf.d/` — static config copied into the image.
- `tests/` — the bash test harness (`tests.sh`) and its expectation fixtures.

## Setup

Everything runs in Docker via `make`. No local nginx is required.

```bash
make build      # build every tag in IMAGE_TAGS, root flavour (.d8)
make test       # run the test suite against the built root images
make all        # build + test, both root and rootless flavours
```

Run a single tag/flavour:

```bash
NGINX_IMAGE_TAG=1.30.2-alpine-slim BUILD_IMAGE_TAG_SUFFIX=d8 BUILD_IMAGE_USER=root \
  make base-build-template
IMAGE_TAG=1.30.2-alpine-slim.d8 ./tests/tests.sh
```

The set of base versions built locally lives in `IMAGE_TAGS` at the top of the
`Makefile`.

## Key Conventions

- **Image-build repo.** Changes are to the Dockerfile, entrypoint, templates,
  config, or tests — never to application code.
- **Features are env-var driven.** New behaviour is added as a template (or
  fragment) plus the matching `envsubst` variable list in `docker-entrypoint.sh`.
  Every variable that a template consumes must be added to the relevant
  `envsubst '...'` allow-list, or it will be stripped to empty.
- **Document every new variable** in `README.md` (the `Env variables` list) and
  add an entry to the `[Unreleased]` section of `CHANGELOG.md`.
- **Two flavours per version:** `:<version>.d8` (root) and
  `:<version>.d8-rootless` (user `1001`), selected by the `user` build-arg.
- **CI version list is the single source of truth.** The published versions are
  defined once in the `NGINX_TAGS` env variable in
  `.github/workflows/docker-publish.yml`; `PRIMARY_TAG` selects the version that
  also gets the rolling `:d8` / `:d8-rootless` tags. Keep `IMAGE_TAGS` in the
  `Makefile` aligned with `NGINX_TAGS` when changing the supported set.

## Code Style

- **Shell**: validated with ShellCheck. Run the repo's dockerised check before
  committing:

  ```bash
  make shellcheck
  ```

- Keep `envsubst` variable allow-lists explicit and in sync across the
  catch-all, default, subfolder, and fragment rendering steps in
  `docker-entrypoint.sh`.
- Match the existing POSIX-sh style of `docker-entrypoint.sh` (no bashisms in
  the entrypoint; the test harness uses bash).

## Git Workflow

### Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<scope>): <description>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`, `perf`, `build`.
**Scope** is optional — use the affected component (e.g. `nginx`, `ci`, `tests`).
Keep the description lowercase, imperative, no trailing period.

Every commit must carry an `Assisted-by` trailer identifying the agent and
model, applied via `git commit --trailer`.

### Branching

- Branch naming: `feat/`, `fix/`, `chore/`, `ci/`, `test/`, `docs/` prefix +
  kebab-case description (e.g. `ci/native-multiarch-release-strategy`).
- **The default branch is `feature/d8`, not `main`/`master`.** Never push
  directly to it — always branch and open a pull request targeting `feature/d8`.

### Rebasing

- Rebase onto `feature/d8` before pushing. No merge commits.
- Use `--force-with-lease` (never `--force`) after rebasing.

## Testing

`make test` builds the images and runs `tests/tests.sh` against each tag in
`IMAGE_TAGS`. The harness boots each image, exercises HTTP behaviour, response
headers, basic auth, CORS, redirects, and the rootless user, and compares
against the fixtures under `tests/expectations` and `tests/overrides/`.

- Test harness: `tests/tests.sh` (bash), helpers in `tests/lib/functions.sh`.
- Run one image directly:
  `IMAGE_TAG=<version>.d8 ./tests/tests.sh`
- Rootless run:
  `IMAGE_TAG=<version>.d8-rootless IMAGE_USER="unknown uid 1001" BASE_TESTS_PORT=8080 ./tests/tests.sh`
- The bare runner's default `IMAGE_TAG` is set at the top of `tests/tests.sh`;
  read it there rather than assuming a value.

## CI/CD

The project uses GitHub Actions. Builds and pushes run only on the `feature/d8`
branch; pull requests run the `prepare` and `test` jobs.

### `docker-publish.yml`

`.github/workflows/docker-publish.yml` is the source of truth; read it for the
exact steps. The pipeline is four jobs:

- `prepare` — surface `NGINX_TAGS` as a job output the matrices read via `fromJSON`.
- `test` — build each version × flavour natively (amd64, `--load`) and run `tests.sh`.
- `build` — build each version × flavour × arch on native runners and push by digest.
- `merge` — assemble the per-arch digests into the final multi-arch manifests.

### `qa.yml`

Runs ShellCheck on the shell scripts.

## Command Safety

### Safe (run autonomously)

Read-only or local, non-destructive:

- `make build`, `make test`, `make all`, `make shellcheck`
- `./tests/tests.sh` (and its `IMAGE_TAG=...` variants)
- `git status`, `git log`, `git diff`
- `docker buildx imagetools inspect <ref>`

### Dangerous (ask user first)

State-changing or outward-facing:

- `git push`, opening or editing pull requests
- `docker push`, `docker buildx build --push`
- Editing `.github/workflows/*` (affects published images)
- Bumping the nginx base version (`NGINX_TAGS` / `IMAGE_TAGS` / `PRIMARY_TAG`)

### Destructive (never run)

- `git push --force` (use `--force-with-lease` only, and only after rebase)
- `rm -rf` on tracked paths
- Deleting GHCR tags or packages
- Force-pushing to `feature/d8`

## Important Rules

- Any new template variable must be added to the matching `envsubst` allow-list
  in `docker-entrypoint.sh`, or it renders empty. This is the most common
  silent failure in this repo.
- Document new env variables in `README.md` and under `[Unreleased]` in
  `CHANGELOG.md`.
- Keep `IMAGE_TAGS` (Makefile) and `NGINX_TAGS` (workflow) aligned.
- Verify the latest nginx version against the registry before bumping — never
  assume it from memory.
- Build and test only in Docker via `make`; run `make shellcheck` before
  committing shell changes.
- Default branch is `feature/d8`: branch and open a PR, never push to it
  directly. See [Command Safety](#command-safety) for the full tier list.
