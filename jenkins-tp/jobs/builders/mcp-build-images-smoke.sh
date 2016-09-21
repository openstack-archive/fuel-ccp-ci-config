#!/bin/bash

set -ex

# This script builds images and use them to run a deployment test.
# If test passes it will push images to registry with "latest" tag.
# Otherwise it will push them with "unstable" tag.
# Logs from building images are downloaded to workspace in ccp.* files

#
# Configuration
#

# fuel devops environment name
export ENV_PREFIX="fuel-ccp-tests"
export ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}
# vm image
export IMAGE_PATH=${IMAGE_PATH}
# workspace directory
export WORKSPACE=${WORKSPACE}
# build images or not
export BUILD_IMAGES=True
# kargo script to deploy k8s
export DEPLOY_SCRIPT=${WORKSPACE}/fuel-ccp-installer/utils/jenkins/kargo_deploy.sh
# tests configuration
export CONF_PATH="fuel_ccp_tests/templates/default.yaml"
# images namespace
export IMAGES_NAMESPACE='mcp'
# leave env after finishing test
export SHUTDOWN_ENV_ON_TEARDOWN=false
# docker registry
export DOCKER_REGISTRY="registry.mcp.fuel-infra.org"

if [[ -z ${IMAGE_PATH} ]]; then
    echo "The IMAGE_PATH variable is not set!"
    exit 1
fi

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

virtualenv $WORKSPACE/venv-fuel-ccp-tests
source $WORKSPACE/venv-fuel-ccp-tests/bin/activate
pushd fuel-ccp-tests
pip install -r fuel_ccp_tests/requirements.txt
pip install -U .
popd

echo "----==== RUN TEST ====----"
cd fuel-ccp-tests
# we want to run next steps even if test fail
set +e
py.test -vvv -s  fuel_ccp_tests/tests/system/test_deploy.py::TestDeployOpenstack::test_fuel_ccp_deploy_microservices
SMOKE_STATUS=$?
set -e

#set tag dependent from test result
if [[ ${SMOKE_STATUS} == 0 ]]; then
    DOCKER_TAG="latest"
else
    DOCKER_TAG="unstable"
fi

MASTER_IP=`awk '/kube_host/ {print $3}' $WORKSPACE/fuel-ccp-tests/${ENV_NAME}_k8s_deployed.ini`

sshpass -p vagrant scp -o StrictHostKeyChecking=no vagrant@${MASTER_IP}:ccp.* .

IMG=`sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@$MASTER_IP docker images --format "{{.Repository}}" | awk -F'/' -v search=/${IMAGES_NAMESPACE}/ '$0 ~ search {print $3}'`

# we need docker config file to authentication in remote repository
sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@$MASTER_IP mkdir -p /home/vagrant/.docker/
sshpass -p vagrant scp -o StrictHostKeyChecking=no /home/jenkins/.docker/config.json vagrant@${MASTER_IP}:~/.docker/

for f in ${IMG}; do
    sshpass  -p vagrant ssh -o StrictHostKeyChecking=no vagrant@$MASTER_IP \
    "docker tag $f ${DOCKER_REGISTRY}/${IMAGES_NAMESPACE}/${f}:${DOCKER_TAG} && docker push ${DOCKER_REGISTRY}/${IMAGES_NAMESPACE}/${f}:${DOCKER_TAG}"
done

dos.py erase ${ENV_NAME}

deactivate
