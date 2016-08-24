#!/bin/bash -x

set -e
env

export ENV_NAME="env-k8s-kargo-$BUILD_TAG"
export IMAGE_PATH="/home/jenkins/workspace/cloud-images/ubuntu-1604-server-13.qcow2"
export DONT_DESTROY_ON_SUCCESS=1
#export VLAN_BRIDGE="" # custom bridge connected to vlan
export DEPLOY_METHOD="kargo"
export SLAVES_COUNT="3"
export WORKSPACE="/home/jenkins/workspace"
export FUEL_DEVOPS_INSTALLATION_DIR="/home/jenkins/venv-fuel-devops-3.0"
echo "Running on $NODE_NAME: $ENV_NAME"
source ${FUEL_DEVOPS_INSTALLATION_DIR}/bin/activate
bash -ex "utils/jenkins/run_k8s_deploy_test.sh"
echo "[TODO] We need some check of K8s deployment here."
echo "Cleaning up:"
dos.py erase $ENV_NAME
