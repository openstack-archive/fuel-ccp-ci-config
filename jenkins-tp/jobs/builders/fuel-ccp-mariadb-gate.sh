#!/bin/bash -xe

virtualenv mariadbenv

source mariadbenv/bin/activate

pip install fuel-ccp/

ccp --images-maintainer mirantis@mirantis.com \
    --images-namespace mariadbbuild --images-tag latest \
    --repositories-names {repos} --builder-no-cache \
    --repositories-path containers/openstack \
    build -c mariadb

deactivate

pushd containers/nextgen/ms-mariadb
tox -e py27
popd
