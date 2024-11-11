cd nextcloud
git pull
git submodule update --init --recursive
cd ..

cd nextcloud/30/apache/
docker build -t cyanwoods/nextcloud:tmp .

cd -
version=$(cat nextcloud/latest.txt)
docker tag nextcloud:tmp nextcloud:
docker build -t cyanwoods/nextcloud:$version -t cyanwoods/nextcloud:lastest .
docker push cyanwoods/nextcloud:$version
docker push cyanwoods/nextcloud:latest

docker rmi nextcloud:tmp
docker rmi cyanwoods/nextcloud:$version
docker rmi cyanwoods/nextcloud:latest
docker builder prune -f
