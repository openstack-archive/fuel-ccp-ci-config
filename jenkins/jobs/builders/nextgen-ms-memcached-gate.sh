#!/bin/bash -xe

virtualenv memcachedenv

source memcachedenv/bin/activate

pip install microservices/

ccp --images-base-distro debian --images-base-tag jessie \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace memcachedbuild --images-tag latest \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate

pushd containers/nextgen/ms-memcached
tox -e py27
popd
