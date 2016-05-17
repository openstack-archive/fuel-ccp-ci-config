#!/bin/bash -xe

virtualenv rabbitmqenv

source rabbitmqenv/bin/activate

cd microservices

pip install .

cd ..

mcp-microservices --images-base_distro debian --images-base_tag 8.4 \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace rabbitmqbuild --images-tag latest \
    --repositories-path containers --auth-gerrit-username nextgen-ci \
    build

deactivate

docker rmi $(docker images | awk '/rabbitmqbuild/ {print $3}')

