#!/bin/bash -xe

virtualenv debianbaseenv

source debianbaseenv/bin/activate

cd microservices

pip install .

cd ..

mcp-microservices --images-base-distro debian --images-base-tag jessie \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace debianbasebuild --images-tag latest \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate
