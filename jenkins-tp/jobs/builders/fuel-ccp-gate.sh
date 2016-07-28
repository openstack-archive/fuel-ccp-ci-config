#!/bin/bash -xe

virtualenv microenv

source microenv/bin/activate

pip install .

ccp --images-maintainer mirantis@mirantis.com \
    --images-namespace microbuild --images-tag latest \
    --repositories-path containers/openstack --builder-no-cache \
build

deactivate

