#!/bin/bash -xe

virtualenv glanceenv

source glanceenv/bin/activate

pip install microservices/

ccp --images-base-distro debian --images-base-tag jessie \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace glancebuild --images-tag latest \
    --repositories-names ms-debian-base,ms-openstack-base,ms-glance \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate
