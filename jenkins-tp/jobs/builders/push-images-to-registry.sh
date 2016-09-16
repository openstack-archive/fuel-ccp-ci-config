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


MASTER_IP=`cat /home/jenkins/workspace/smoke/config_k8s_deployed.ini | grep kube_host | awk '{print $3}'`


IMG=`sshpass -p vagrant "ssh vagrant@$MASTER_IP docker images | grep ${DOCKER_NAMESPACE} | awk 'NR>1{print $1}' | cut -d / -f 3"`

sshpass -p vagrant "scp /home/jenkins/.dockercfg vagrant@${MASTER_IP}:~/"

for f in ${IMG}
do
    sshpass  -p vagrant "ssh vagrant@$MASTER_IP docker tag $f ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/$f:<tag_nr-fail-or-ok>"
    sshpass  -p vagrant "ssh vagrant@$MASTER_IP docker push ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/$f:<tag_nr-fail-or-ok>"
done
