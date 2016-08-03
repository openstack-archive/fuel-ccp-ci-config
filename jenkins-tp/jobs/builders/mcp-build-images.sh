#!/bin/bash -ex

# Builds MCP images and pushes them to Docker registry with configurable
# tag.
# Optionallyh it can purge n older images (works correctly if tag is
# numerical).
# This script assumes that user is already authenticated to Docker
# registry (e.g. by running 'docker login').


# CONFIGURATION:
######################################################
DOCKER_REGISTRY="registry.mcp.fuel-infra.org"
DOCKER_NAMESPACE="mcp"
IMAGES_MAINTAINER="mos-microservices@mirantis.com"
REPOSITORIES_PATH="microservices-repos"
TAG="latest"
PURGE="false"


# Parse command-line options:
OPTS=`getopt -o '' --long tag:,purge: -n 'parse-options' -- ${@}`
if [ ${?} != 0 ] ; then
  exit_script "Failed parsing options."
fi
eval set -- ${OPTS}

while true; do
  case ${1} in
    --tag ) TAG=${2}; shift; shift ;;
    --purge ) PURGE="true"; PURGE_COUNT=${2}; shift; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done


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
build
deactivatea


# Purge images if requested:
if [ ${PURGE} == "true" ] && [[ ${TAG} =~ ^[0-9]+$ ]];
then
  TAG_TO_DELETE=`expr ${TAG} - ${PURGE_COUNT}`
  #FIXME (mzawadzki): remove 'echo' after tests to really rmi images
  #FIXME (mzawadzki): this will not remove images locally but not from
  #remote registry
  docker images| tail -n +1| awk -v TAG_TO_DELETE=${TAG_TO_DELETE} \
  '$2 == TAG_TO_DELETE {system("echo docker rmi  " $1 ":"TAG_TO_DELETE);}'\
  && true
fi
