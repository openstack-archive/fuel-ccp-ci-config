#!/bin/bash

# [TODO: mzawadzki] Temporary, to be uncommented after job is tested.
# set -ex
env

export ENV_NAME="env-k8s-kargo-$BUILD_TAG"
export IMAGE_PATH="/home/jenkins/workspace/cloud-images/packer-ubuntu-1604-server-new.qcow2"
export DONT_DESTROY_ON_SUCCESS=1
#export VLAN_BRIDGE="" # custom bridge connected to vlan
export DEPLOY_METHOD="kargo"
export SLAVES_COUNT="3"
export WORKSPACE="/home/jenkins/workspace"
export CUSTOM_YAML='kube_network_plugin: "calico"
kube_proxy_mode: "iptables"
cloud_provider: "generic"
hyperkube_image_repo: "quay.io/coreos/hyperkube"
hyperkube_image_tag: "v1.2.6_coreos.0"
kube_version: "v1.2.6"'
echo "Running on $NODE_NAME: $ENV_NAME"
bash -ex "utils/jenkins/run_k8s_deploy_test.sh"
echo "[TODO] We need some check of K8s deployment here."
echo "Cleaning up:"
dos.py erase $ENV_NAME

# [TODO: mzawadzki] Temporary wourkaround,to be changed after job is tested.
exit 0
