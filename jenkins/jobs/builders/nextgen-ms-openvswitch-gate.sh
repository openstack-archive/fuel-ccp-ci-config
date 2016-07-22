#!/bin/bash -xe

virtualenv ovsenv

source ovsenv/bin/activate

pip install microservices/

ccp --images-base-distro debian --images-base-tag jessie \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace ovsbuild --images-tag latest \
    --repositories-names ms-debian-base,ms-openvswitch \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate
