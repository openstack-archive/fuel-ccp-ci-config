#!/bin/bash -x

set -e
env

export ENV_NAME="env-k8s-kargo-$BUILD_TAG"
export IMAGE_PATH="/home/jenkins/workspace/cloud-images/default-image.qcow2"
export DONT_DESTROY_ON_SUCCESS=1
#export VLAN_BRIDGE="" # custom bridge connected to vlan
export DEPLOY_METHOD="kargo"
export SLAVES_COUNT="3"
export WORKSPACE="/home/jenkins/workspace"
export FUEL_DEVOPS_INSTALLATION_DIR="/home/jenkins/venv-fuel-devops-3.0"
export CUSTOM_YAML='hyperkube_image_repo: "artifactory.mcp.mirantis.net:5000/hyperkube-amd64"
hyperkube_image_tag: "v1.4.0-beta.10-3-gf36f43_108"'
echo "Running on $NODE_NAME: $ENV_NAME"
source ${FUEL_DEVOPS_INSTALLATION_DIR}/bin/activate
echo "Use image:"
ls -la $IMAGE_PATH
bash -ex "utils/jenkins/run_k8s_deploy_test.sh"
echo "[TODO] We need some check of K8s deployment here."
echo "Cleaning up:"
dos.py erase $ENV_NAME
