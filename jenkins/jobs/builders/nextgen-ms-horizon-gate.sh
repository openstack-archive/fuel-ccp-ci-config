#!/bin/bash -xe

virtualenv horizonenv

source horizonenv/bin/activate

cd microservices

pip install .

cd ..

mcp-microservices --images-base_distro debian --images-base_tag 8.4 \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace horizonbuild --images-tag latest \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate

