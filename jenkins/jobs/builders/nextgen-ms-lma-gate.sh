#!/bin/bash -xe

virtualenv lmaenv

source lmaenv/bin/activate

cd microservices

pip install .

cd ..

mcp-microservices --images-base-distro debian --images-base-tag 8.4 \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace lmabuild --images-tag latest \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate


