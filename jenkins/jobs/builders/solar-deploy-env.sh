#!/bin/bash

set -ex

export ENV_NAME="solar-k8s-env-$BUILD_NUMBER.$BUILD_ID"
export IMAGE_PATH="/home/jenkins/workspace/cloud-images/alpine-img.qcow2"
export MASTER_IMAGE_PATH="/home/jenkins/workspace/cloud-images/fedora-23-x86_64.qcow2"
export DONT_DESTROY_ON_SUCCESS=1

source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
echo "Running on $NODE_NAME: $ENV_NAME"

sh -x "utils/jenkins/run_k8s_deploy_test.sh"
deactivate

echo "Entering infinite loop to lock slot on this Jenkins worker."
echo "To release this environment please abort this job."
set +x
while [ 1 ]; do sleep 60m; done
