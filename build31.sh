#!/usr/bin/env bash
set -euo pipefail

cd nextcloud
git checkout master
git pull
git submodule update --init --recursive
cd ..

cd nextcloud/31/apache/
docker build -t cyanwoods/nextcloud:tmp .

cd -
version=$(jq -r '."31".version' nextcloud/versions.json)
if [[ -z "$version" || "$version" == "null" ]]; then
    echo "Error: version 31 not found in nextcloud/versions.json" >&2
    exit 1
fi
docker build -t "cyanwoods/nextcloud:$version" -t cyanwoods/nextcloud:latest .
docker push "cyanwoods/nextcloud:$version"
docker push cyanwoods/nextcloud:latest

docker rmi cyanwoods/nextcloud:tmp
docker rmi "cyanwoods/nextcloud:$version"
docker rmi cyanwoods/nextcloud:latest
docker builder prune -f
