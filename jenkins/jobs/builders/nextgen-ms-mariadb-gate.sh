#!/bin/bash -xe

virtualenv mariadbenv

source mariadbenv/bin/activate

pip install .

mcp-microservices --images-base_distro debian --images-base_tag 8.4 \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace mariadbbuild --images-tag latest \
    --repositories-path mirantis/k8s --auth-gerrit-username nextgen-ci \
    build

deactivate

docker rmi $(docker images | awk '/mariadbbuild/ {print $3}')

