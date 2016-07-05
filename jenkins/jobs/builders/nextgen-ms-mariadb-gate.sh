#!/bin/bash -xe

virtualenv mariadbenv

source mariadbenv/bin/activate

pip install microservices/

mcp-microservices --images-base-distro debian --images-base-tag jessie \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace mariadbbuild --images-tag latest \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate

pushd containers/nextgen/ms-mariadb
tox -e py27
popd
