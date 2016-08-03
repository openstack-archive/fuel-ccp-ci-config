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
[ -z "$TAG" ] && TAG="latest"
[ -z "$PURGE" ] && PURGE="false"
[ -z "$PURGE_COUNT" ] && PURGE_COUNT="5"


# Install fuel-ccp:
virtualenv mcp
source mcp/bin/activate
pip install .

# Build images:
ccp \
--builder-no-cache \
--builder-push \
--registry-address $DOCKER_REGISTRY \
--images-namespace $DOCKER_NAMESPACE \
--images-tag $TAG \
--images-maintainer $IMAGES_MAINTAINER \
--repositories-path $REPOSITORIES_PATH \
build
deactivate


# Purge images if requested:
if [ $PURGE == "true" ] && [[ $TAG =~ ^[0-9]+$ ]];
then
  TAG_TO_DELETE=`expr $TAG - $PURGE_COUNT`
  #FIXME (mzawadzki): remove 'echo' after tests to really rmi images
  #FIXME (mzawadzki): this will remove images locally but not from
  #remote registry
  docker images| tail -n +1| awk -v TAG_TO_DELETE=$TAG_TO_DELETE \
  '$2 == TAG_TO_DELETE {system("echo docker rmi  " $1 ":"TAG_TO_DELETE);}'\
  && true
fi
