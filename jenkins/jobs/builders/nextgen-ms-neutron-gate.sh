#!/bin/bash -xe

virtualenv neutronenv

source neutronenv/bin/activate

pip install microservices/

mcp-microservices --images-maintainer mirantis@mirantis.com \
    --images-namespace neutronbuild --images-tag latest \
    --repositories-names ms-debian-base,ms-openstack-base,ms-neutron \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate

