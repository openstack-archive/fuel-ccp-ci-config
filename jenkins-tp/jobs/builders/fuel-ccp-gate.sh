#!/bin/bash -xe

virtualenv microenv

source microenv/bin/activate

pip install .

mcp-microservices --images-maintainer mirantis@mirantis.com \
    --images-namespace microbuild --images-tag latest \
    --repositories-path mirantis/k8s \
build

deactivate

