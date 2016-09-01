#!/bin/bash -ex

# Removes unwanted tags from Docker registry.
# This scripts expects that authenitcation to Docker registry is configured
# beforehand (e.g. by running docker login).
# (c) mzawadzki@mirantis.com

# CONFIGURATION:
######################################################
: ${LEAVE_LAST_RECENT_TAGS:="6"}
: ${DOCKER_NAMESPACE:="mcp"}
: ${DOCKER_REGISTRY:="registry.mcp.fuel-infra.org"}
REGISTRY_MANAGER="registry-manage --host ${DOCKER_REGISTRY}"

[[ ! ${LEAVE_LAST_RECENT_TAGS} =~ ^[0-9]+$ ]] && exit 1

for image in `${REGISTRY_MANAGER} list | grep "^${DOCKER_NAMESPACE}/"`
do
  ${REGISTRY_MANAGER} list-tags ${image} | \
  grep "^[0-9]\+$" | sort -rn | tail -n +`expr ${LEAVE_LAST_RECENT_TAGS} + 1` | \
  awk -v REGISTRY_MANAGER="${REGISTRY_MANAGER}" -v image=${image} \
  '$1 ~ /^[0-9]+$/ {system(REGISTRY_MANAGER" delete "image":"$1);}'
done
