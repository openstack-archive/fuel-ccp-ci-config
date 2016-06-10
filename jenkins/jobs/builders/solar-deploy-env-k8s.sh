#!/bin/bash

set -ex

export ENV_NAME="solar-k8s-env-$BUILD_TAG"
export MASTER_IMAGE_PATH="/home/jenkins/workspace/cloud-images/alpine-img.qcow2"
export IMAGE_PATH="/home/jenkins/workspace/cloud-images/packer-ubuntu-1604-server.qcow2"
export DONT_DESTROY_ON_SUCCESS=1
export VLAN_BRIDGE="vlan450"
export DEPLOY_METHOD="solar"

source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
echo "Running on $NODE_NAME: $ENV_NAME"

bash -x "utils/jenkins/run_k8s_deploy_test.sh"
deactivate
echo "Deploying local registry"
mkdir bin
cd bin
curl -O https://storage.googleapis.com/kubernetes-release/release/v1.2.4/bin/linux/amd64/kubectl
chmod +x kubectl
cd ..
export PATH=$PATH:$WORKSPACE/bin

cubeip=`cat VLAN_IPS | head -n 1`

kubectl -s $cubeip:8080 create -f ./registry/registry-pod.yaml
kubectl -s $cubeip:8080 create -f ./registry/service-registry.yaml

echo "Entering infinite loop to lock slot on this Jenkins worker."
echo "To release this environment please abort this job."
set +x
while [ 1 ]; do sleep 60m; done
