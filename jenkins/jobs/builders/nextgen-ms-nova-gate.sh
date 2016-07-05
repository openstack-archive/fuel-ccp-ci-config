#!/bin/bash -xe

virtualenv novaenv

source novaenv/bin/activate

pip install microservices/

mcp-microservices --images-base-distro debian --images-base-tag jessie \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace novabuild --images-tag latest \
    --repositories-names ms-debian-base,ms-openstack-base,ms-nova \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate

