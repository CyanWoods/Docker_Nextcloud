#!/usr/bin/env bash
set -euo pipefail

# Usage: ./buildx.sh <nextcloud-major-version> [platforms] [--no-cache]
# Example: ./buildx.sh 33
# Example: ./buildx.sh 33 linux/amd64,linux/arm64
# Example: ./buildx.sh 33 linux/amd64,linux/arm64 --no-cache

MAJOR="${1:-}"
PLATFORMS="${2:-linux/amd64,linux/arm64}"
NO_CACHE_FLAG="${3:-}"
BUILDER="nextcloud-buildx"
REPO="cyanwoods/nextcloud"

if [[ -z "$MAJOR" ]]; then
    echo "Usage: $0 <nextcloud-major-version> [platforms] [--no-cache]" >&2
    echo "Example: $0 33" >&2
    echo "Example: $0 33 linux/amd64" >&2
    echo "Example: $0 33 linux/amd64,linux/arm64 --no-cache" >&2
    exit 1
fi

NO_CACHE=""
if [[ "$NO_CACHE_FLAG" == "--no-cache" ]]; then
    NO_CACHE="--no-cache"
    echo "Cache disabled"
fi

# Update submodule
cd nextcloud
git checkout master
git pull
git submodule update --init --recursive
cd ..

if [[ ! -d "nextcloud/$MAJOR/apache" ]]; then
    echo "Error: nextcloud/$MAJOR/apache/ not found" >&2
    exit 1
fi

# Ensure a dedicated buildx builder exists (docker-container driver supports multi-platform)
if ! docker buildx inspect "$BUILDER" &>/dev/null; then
    echo "Creating buildx builder: $BUILDER"
    docker buildx create --name "$BUILDER" --driver docker-container --bootstrap
fi
docker buildx use "$BUILDER"

VERSION="$(cat nextcloud/latest.txt)"
echo "Building Nextcloud $VERSION for platforms: $PLATFORMS"

# Stage 1: build and push the upstream base image
# Multi-platform images cannot be loaded locally, so --push is required.
echo "==> Stage 1: upstream base -> $REPO:tmp"
docker buildx build \
    --platform "$PLATFORMS" \
    --tag "$REPO:tmp" \
    --push \
    $NO_CACHE \
    "nextcloud/$MAJOR/apache/"

# Stage 2: build and push the customized final image
echo "==> Stage 2: customized image -> $REPO:$VERSION / $REPO:latest"
docker buildx build \
    --platform "$PLATFORMS" \
    --tag "$REPO:$VERSION" \
    --tag "$REPO:latest" \
    --push \
    $NO_CACHE \
    .

echo "==> Done: pushed $REPO:$VERSION and $REPO:latest"

# Prune the builder cache to free disk space
docker buildx prune -f --builder "$BUILDER"
