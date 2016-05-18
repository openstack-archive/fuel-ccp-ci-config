#!/bin/bash

set -ex

export ENV_NAME="solar-k8s-env-$BUILD_NUMBER.$BUILD_ID"
export MASTER_IMAGE_PATH="/home/jenkins/workspace/cloud-images/alpine-img.qcow2"
export IMAGE_PATH="/home/jenkins/workspace/cloud-images/packer-ubuntu-1604-server.qcow2"
export DONT_DESTROY_ON_SUCCESS=1
export VLAN_BRIDGE="vlan450"

source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
echo "Running on $NODE_NAME: $ENV_NAME"

pushd mcpinstaller
sh -x "utils/jenkins/run_k8s_deploy_test.sh"
popd

echo "Deploying OpenStack"
mkdir bin
cd bin
curl -O https://storage.googleapis.com/kubernetes-release/release/v1.2.4/bin/linux/amd64/kubectl
chmod +x kubectl
cd ..
export PATH=$PATH:$WORKSPACE/bin

cd microservices
pip install .
cd ..

cubeip=`cat ./mcpinstaller/VLAN_IPS | head -n 1`

mcp-microservices \
    --images-base_distro debian \
    --images-base_tag 8.4 \
    --images-maintainer mos-microservices@mirantis.com \
    --auth-gerrit-username nextgen-ci \
    --auth-registry \
    --builder-registry registry01-bud.ng.mirantis.net \
    --images-namespace nextgen \
    --images-tag latest \
    --repositories-path microservices-repos \
    --kubernetes-server $cubeip:8080 \
    deploy

deactivate

echo "Entering infinite loop to lock slot on this Jenkins worker."
echo "To release this environment please abort this job."
set +x
while [ 1 ]; do sleep 60m; done
