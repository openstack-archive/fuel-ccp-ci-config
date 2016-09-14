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
cat > ccp-test.yaml << EOF
debug: True
builder:
  no_cache: True
  push: True
images:
  namespace: ${DOCKER_NAMESPACE}
  tag: ${TAG}
  maintainer: mirantis@mirantis.com
repositories:
  path: ${REPOSITORIES_PATH}
  skip_empty: Truei
registry:
  address: ${DOCKER_REGISTRY}
EOF

ccp --config-file ccp-test.yaml build

deactivate
