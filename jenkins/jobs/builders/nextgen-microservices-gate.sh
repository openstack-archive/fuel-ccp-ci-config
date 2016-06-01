#!/bin/bash -xe

virtualenv microenv

source microenv/bin/activate

pip install .

mcp-microservices --images-base-distro debian --images-base-tag 8.4 \
--images-maintainer mirantis@mirantis.com \
--images-namespace microbuild --images-tag latest \
--repositories-path mirantis/k8s --auth-gerrit-username nextgen-ci \
build

deactivate

