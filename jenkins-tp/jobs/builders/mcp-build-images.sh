#!/bin/bash -ex

# Builds MCP images and pushes them to Docker registry with configurable
# tag.
# Optionally it can purge n older images (works correctly if tag is
# numerical).
# This script assumes that user is already authenticated to Docker
# registry (e.g. by running 'docker login').
# Parameters must be passed via env variables.


# CONFIGURATION:
######################################################
DOCKER_REGISTRY="registry.mcp.fuel-infra.org"
DOCKER_NAMESPACE="mcp"
IMAGES_MAINTAINER="mos-microservices@mirantis.com"
REPOSITORIES_PATH="microservices-repos"
: ${TAG:="latest"}


# Install fuel-ccp:
virtualenv mcp
source mcp/bin/activate
pip install .

# Build images:
ccp \
--builder-no-cache \
--builder-push \
--registry-address ${DOCKER_REGISTRY} \
--images-namespace ${DOCKER_NAMESPACE} \
--images-tag ${TAG} \
--images-maintainer ${IMAGES_MAINTAINER} \
--repositories-path ${REPOSITORIES_PATH} \
--debug \
build

deactivate
