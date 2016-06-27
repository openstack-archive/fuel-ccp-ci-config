#!/bin/bash -xe

virtualenv memcachedenv

source memcachedenv/bin/activate

pip install microservices/

mcp-microservices --images-base-distro debian --images-base-tag 8.4 \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace memcachedbuild --images-tag latest \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate

pushd containers/nextgen/ms-memcached
tox -e py27
popd