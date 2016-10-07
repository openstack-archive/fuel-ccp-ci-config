#!/bin/bash -ex

# Removes unwanted tags from Docker registry.
# This scripts expects that authenitcation to Docker registry is configured
# beforehand (e.g. by running docker login).
# (c) mzawadzki@mirantis.com

# CONFIGURATION:
######################################################
: ${DOCKER_NAMESPACE:="mcp"}
: ${DOCKER_REGISTRY:="registry.mcp.fuel-infra.org"}
REGISTRY_MANAGER="registry-manage --host ${DOCKER_REGISTRY}"
TAG_REGEXP=${PARAM_TAG_REGEXP}


# List all tags for all images, select and delete tags matching TAG_REGEXP:
# 
# Sample output from registry-manage tool:
# "list" subcommand:
# mcp/base
# mcp/base-tools
# mcp/cron
# mcp/elasticsearch
# mcp/etcd
# "list-tags mcp/base" subcommand:
# 21
# 22
# latest
# 16
# new
for image in `${REGISTRY_MANAGER} list | grep "^${DOCKER_NAMESPACE}/"`; do
    ${REGISTRY_MANAGER} list-tags ${image} | \
    grep "${TAG_REGEXP}"  | \
    awk -v REGISTRY_MANAGER="${REGISTRY_MANAGER}" -v image="${image}" \
        -v TAG_REGEXP="${TAG_REGEXP}" \
        '$1 ~ TAG_REGEXP {exit system(REGISTRY_MANAGER" delete "image":"$1);}'
done
