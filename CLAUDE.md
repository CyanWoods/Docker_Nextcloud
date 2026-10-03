# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Does

This project builds customized Nextcloud Docker images on top of the official Nextcloud Apache images. It adds extra system packages (ffmpeg, ghostscript, certbot, smbclient, supervisor, etc.) and compiles additional PHP extensions (bz2, smbclient via PECL) that are not included in the upstream image.

The `nextcloud/` directory is a git submodule pointing to the official [nextcloud/docker](https://github.com/nextcloud/docker) repository.

## Build Commands

The generic build script accepts the major Nextcloud version as an argument:

```bash
./build.sh 33   # Build for Nextcloud 33.x
```

Version-specific convenience wrappers exist for each supported major version:

```bash
./build31.sh    # Nextcloud 31.x
./build32.sh    # Nextcloud 32.x
./build33.sh    # Nextcloud 33.x (current)
```

Each build script:
1. Pulls the latest upstream changes from the `nextcloud` submodule
2. Builds an intermediate image (`cyanwoods/nextcloud:tmp`) from `nextcloud/<version>/apache/Dockerfile`
3. Builds the final customized image using the root `Dockerfile` (which `FROM cyanwoods/nextcloud:tmp`)
4. Tags the result as `cyanwoods/nextcloud:<version>` and `cyanwoods/nextcloud:latest` (version string read from `nextcloud/latest.txt`)
5. Pushes both tags to Docker Hub
6. Removes all local intermediate and final images, then prunes the build cache

For multi-platform builds (amd64 + arm64), use `buildx.sh`:

```bash
./buildx.sh 33                                    # default: linux/amd64,linux/arm64
./buildx.sh 33 linux/amd64,linux/arm64 --no-cache
```

`buildx.sh` pushes the upstream base as `cyanwoods/nextcloud-origin:<version>` / `:latest`
and the final image as `cyanwoods/nextcloud:<version>` / `:latest`.

## Architecture

**Two-stage build strategy:**
- Stage 1: `nextcloud/<version>/apache/Dockerfile` → upstream base image
  - `build.sh`: local tag `cyanwoods/nextcloud:tmp`
  - `buildx.sh`: pushed as `cyanwoods/nextcloud-origin:<version>` + `cyanwoods/nextcloud-origin:latest`
- Stage 2: Root `Dockerfile` → `cyanwoods/nextcloud:<version>` (customized final image)

**Root Dockerfile adds:**
- APT packages: `vim`, `sudo`, `ssl-cert`, `certbot`, `python3-certbot-apache`, `ffmpeg`, `ghostscript`, `procps`, `smbclient`, `supervisor`
- PHP extensions: `bz2` (via `docker-php-ext-install`) and `smbclient` (via PECL)
- Build-time deps (`libbz2-dev`, `libsmbclient-dev`) are installed then auto-removed after extension compilation to keep the image lean
- Apache SSL module and default-ssl site enabled
- Apache conf `photokit-501.conf` (enabled via `a2enconf`): returns `501` for the iOS client's PhotoKit probe (`OPTIONS` requests carrying `X-NC-PhotoKit-Upload: 1`), so clients fall back to normal upload since the server has no resumable-upload support
- `supervisord` replaces the default entrypoint CMD to run both Apache and the Nextcloud cron job in one container

**supervisord.conf** manages two processes:
- `apache2-foreground` — the web server
- `/cron.sh` — Nextcloud's built-in cron script

## Adding a New Major Version

When Nextcloud releases a new major version (e.g., 34):
1. Update the `nextcloud` submodule to include the new version directory
2. Create `build34.sh` by copying `build33.sh` and replacing `33` with `34`
3. Update `build.sh` if the default version should change
4. Verify `nextcloud/34/apache/Dockerfile` exists after the submodule update

## Submodule Management

```bash
# Update submodule to latest upstream
cd nextcloud && git checkout master && git pull && git submodule update --init --recursive && cd ..
```
