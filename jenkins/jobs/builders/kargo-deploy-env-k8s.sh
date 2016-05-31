#!/bin/bash

set -ex

export ENV_NAME="kargo-k8s-env-$BUILD_NUMBER.$BUILD_ID"
export MASTER_IMAGE_PATH="/home/jenkins/workspace/cloud-images/alpine-img.qcow2"
export IMAGE_PATH="/home/jenkins/workspace/cloud-images/packer-ubuntu-1604-server.qcow2"
export DONT_DESTROY_ON_SUCCESS=1
export VLAN_BRIDGE="vlan450"
export DEPLOY_METHOD="kargo"

source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
echo "Running on $NODE_NAME: $ENV_NAME"

sh -x "utils/jenkins/run_k8s_deploy_test.sh"
deactivate

echo "Entering infinite loop to lock slot on this Jenkins worker."
echo "To release this environment please abort this job."
set +x
while [ 1 ]; do sleep 60m; done
