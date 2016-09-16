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

# TODO: copy docker login file from slave to vm 

IMG=`sshpass -l vagrant -p vagrant $MASTER_IP docker images | grep SOME_NAMESPACE` #TODO extract list of components

for f in $IMG
do
  sshpass -l vagrant -p vagrant $MASTER_IP docker tag $f <registry>/<namespace>/$f:<tag_nr-fail-or-ok>
  sshpass -l vagrant -p vagrant $MASTER_IP docker push <registry>/<namespace>/$f:<tag_nr-fail-or-ok    >  
done

