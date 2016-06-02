#!/bin/bash -xe

virtualenv memcachedenv

source memcachedenv/bin/activate

cd microservices

pip install .

cd ..

mcp-microservices --images-base-distro debian --images-base-tag 8.4 \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace memcachedbuild --images-tag latest \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

ts=`date +%s`

docker run -d --name memcached-${ts} -it memcachedbuild/memcached:latest
sleep 2
ip=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' memcached-${ts}`

echo "stats" | nc ${ip} 11211

docker stop memcached-${ts}
docker rm memcached-${ts}

deactivate

