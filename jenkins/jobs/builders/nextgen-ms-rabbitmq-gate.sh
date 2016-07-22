#!/bin/bash -xe

virtualenv rabbitmqenv

source rabbitmqenv/bin/activate

cd microservices

pip install .

cd ..

ccp --images-base-distro debian --images-base-tag jessie \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace rabbitmqbuild --images-tag latest \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

deactivate

