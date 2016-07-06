#!/bin/bash -xe

virtualenv memcachedenv

source memcachedenv/bin/activate

pip install fuel-ccp/

mcp-microservices --images-maintainer mirantis@mirantis.com \
    --images-namespace memcachedbuild --images-tag latest \
    --repositories-path containers/nextgen \
    build

deactivate

pushd containers/nextgen/ms-memcached
tox -e py27
popd
