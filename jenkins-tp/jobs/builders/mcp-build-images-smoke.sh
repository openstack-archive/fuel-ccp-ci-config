#!/bin/bash

#set -ex

# This script run QA smoke test. It's build images and test deploy of them.
# If test pass it push images to registry with tag latest.
# If test doesn't pass it push images to registry with tag unstable.
# Logs from building images are in ccp.* files downloaded to workspace.


if [[ -z ${IMAGE_PATH} ]]; then
    echo "The IMAGE_PATH variable is not set!"
    exit -1
fi

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

TEST_IMAGE_JOB_URL="${JENKINS_URL}job/0.1-mcp.test_all/"

virtualenv $WORKSPACE/venv-fuel-ccp-tests
source $WORKSPACE/venv-fuel-ccp-tests/bin/activate
pushd fuel-ccp-tests
pip install -r fuel_ccp_tests/requirements.txt
pip install -U .
popd


export ENV_PREFIX="fuel-ccp-tests"
ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
ENV_NAME=${ENV_NAME:0:68}
# fuel devops environment name
export ENV_NAME=${ENV_NAME}
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
# ??
export SMOKE_STATUS=0
# leave env after finishing test
export SHUTDOWN_ENV_ON_TEARDOWN=false
# docker registry
export DOCKER_REGISTRY="registry.mcp.fuel-infra.org"


echo "----==== RUN TEST ====----"
cd fuel-ccp-tests
py.test -vvv -s  fuel_ccp_tests/tests/system/test_deploy.py::TestDeployOpenstack::test_fuel_ccp_deploy_microservices
SMOKE_STATUS=$?

#set tag dependent from test result
if [[ ${SMOKE_STATUS} == 0 ]]; then
    DOCKER_TAG="latest"
else
    DOCKER_TAG="unstable"
fi

MASTER_IP=`awk '/kube_host/{print $3}' /home/jenkins/workspace/smoke/${ENV_NAME}_k8s_deployed.ini`

sshpass -p vagrant scp vagrant@${MASTER_IP}:ccp.* .

IMG=`sshpass -p vagrant ssh vagrant@$MASTER_IP docker images --format "{{.Repository}}" | grep ${IMAGES_NAMESPACE} | cut -d / -f 3`

sshpass -p vagrant ssh vagrant@$MASTER_IP mkdir -p /home/jenkins/.docker/
sshpass -p vagrant scp /home/jenkins/.docker/config.json vagrant@${MASTER_IP}:~/.docker/

for f in ${IMG}; do
    sshpass  -p vagrant ssh vagrant@$MASTER_IP \
    "docker tag $f ${DOCKER_REGISTRY}/${IMAGES_NAMESPACE}/${f}:${DOCKER_TAG} && docker push ${DOCKER_REGISTRY}/${IMAGES_NAMESPACE}/${f}:${DOCKER_TAG}"
done

dos.py erase ${ENV_NAME}

deactivate
