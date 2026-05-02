#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <nextcloud-major-version>" >&2
    echo "Example: $0 33" >&2
    exit 1
fi

cd nextcloud
git checkout master
git pull
git submodule update --init --recursive
cd ..

cd nextcloud/"$1"/apache/
docker build -t cyanwoods/nextcloud:tmp .

cd -
version=$(jq -r ".\"$1\".version" nextcloud/versions.json)
if [[ -z "$version" || "$version" == "null" ]]; then
    echo "Error: version not found for major $1 in nextcloud/versions.json" >&2
    exit 1
fi
docker build -t "cyanwoods/nextcloud:$version" -t cyanwoods/nextcloud:latest .
docker push "cyanwoods/nextcloud:$version"
docker push cyanwoods/nextcloud:latest

docker rmi cyanwoods/nextcloud:tmp
docker rmi "cyanwoods/nextcloud:$version"
docker rmi cyanwoods/nextcloud:latest
docker builder prune -f
