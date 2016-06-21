#!/bin/bash

set -ex

env

export ENV_NAME="kargo-k8s-env-$BUILD_TAG"
export IMAGE_PATH="/home/jenkins/workspace/cloud-images/packer-ubuntu-1604-server-new.qcow2"
export DONT_DESTROY_ON_SUCCESS=1
export VLAN_BRIDGE="vlan450"
export DEPLOY_METHOD="kargo"
export SLAVES_COUNT=$PARAM_SLAVES_COUNT
export WORKSPACE="/home/jenkins/workspace"
export CUSTOM_YAML='kube_network_plugin: "calico"
#Required for calico
kube_proxy_mode: "iptables"'

source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
echo "Running on $NODE_NAME: $ENV_NAME"

bash -x "utils/jenkins/run_k8s_deploy_test.sh"
deactivate

echo "Entering infinite loop to lock slot on this Jenkins worker."
echo "To release this environment please abort this job."
set +x
while [ 1 ]; do sleep 60m; done
