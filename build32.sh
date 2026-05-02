#!/usr/bin/env bash
set -euo pipefail

cd nextcloud
git checkout master
git pull
git submodule update --init --recursive
cd ..

cd nextcloud/32/apache/
docker build -t cyanwoods/nextcloud:tmp .

cd -
version=$(cat nextcloud/latest.txt)
docker build -t "cyanwoods/nextcloud:$version" -t cyanwoods/nextcloud:latest .
docker push "cyanwoods/nextcloud:$version"
docker push cyanwoods/nextcloud:latest

docker rmi cyanwoods/nextcloud:tmp
docker rmi "cyanwoods/nextcloud:$version"
docker rmi cyanwoods/nextcloud:latest
docker builder prune -f
