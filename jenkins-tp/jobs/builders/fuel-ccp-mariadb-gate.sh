#!/bin/bash -xe

virtualenv mariadbenv

source mariadbenv/bin/activate

pip install fuel-ccp/

mcp-microservices --images-maintainer mirantis@mirantis.com \
    --images-namespace mariadbbuild --images-tag latest \
    --repositories-path containers/nextgen \
    build

deactivate

pushd containers/nextgen/ms-mariadb
tox -e py27
popd
