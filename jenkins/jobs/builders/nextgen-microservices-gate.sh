#!/bin/bash -xe

virtualenv microenv

source microenv/bin/activate

REPO_PATH="microservices/nextgen"

pip install .

# build images
mcp-microservices --images-base-distro debian --images-base-tag 8.4 \
--images-maintainer mirantis@mirantis.com \
--images-namespace microbuild --images-tag latest \
--repositories-path "$REPO_PATH" --auth-gerrit-username nextgen-ci \
build

# dry-run deploy components
mcp-microservices --repositories-path "$REPO_PATH" deploy --dry-run

deactivate
