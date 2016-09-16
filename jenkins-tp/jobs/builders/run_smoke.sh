#!/bin/bash

#set -ex

if [[ -z ${IMAGE_PATH} ]]; then
    echo "The IMAGE_PATH variable is not set!"
    exit -1
fi

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

TEST_IMAGE_JOB_URL="${JENKINS_URL}job/0.1-mcp.test_all/"

virtualenv $WORKSPACE/venv-fuel-ccp-tests
source $WORKSPACE/venv-fuel-ccp-tests/bin/activate
cd fuel-ccp-tests
pip install -r fuel_ccp_tests/requirements.txt
pip install -U .
cd ..
export ENV_PREFIX="fuel-ccp-tests"


ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
ENV_NAME=${ENV_NAME:0:68}
export ENV_NAME=${ENV_NAME}
export IMAGE_PATH=${IMAGE_PATH}
export WORKSPACE=${WORKSPACE}
export BUILD_IMAGES=True
export DEPLOY_SCRIPT=${WORKSPACE}/fuel-ccp-installer/utils/jenkins/kargo_deploy.sh
export CONF_PATH="fuel_ccp_tests/templates/default.yaml"
export IMAGES_NAMESPACE='mcp'
export SMOKE_STATUS=0
export DOCKER_TAG
export SHUTDOWN_ENV_ON_TEARDOWN=false
export DOCKER_REGISTRY="registry.mcp.fuel-infra.org"
export IMAGES_MAINTAINER="mos-microservices@mirantis.com"
export REPOSITORIES_PATH="microservices-repos"


echo "----==== RUN TEST ====----"
cd fuel-ccp-tests

py.test -vvv -s  fuel_ccp_tests/tests/system/test_deploy.py::TestDeployOpenstack::test_fuel_ccp_deploy_microservices
SMOKE_STATUS=$?

if [[ ${SMOKE_STATUS} == 0 ]]; then
    DOCKER_TAG="latest"
else
    DOCKER_TAG="unstable"
fi
deactivate

MASTER_IP=`cat /home/jenkins/workspace/smoke/config_k8s_deployed.ini | grep kube_host | awk '{print $3}'`

IMG=`sshpass -p vagrant ssh vagrant@$MASTER_IP docker images | grep ${IMAGES_NAMESPACE} | awk 'NR>1{print $1}' | cut -d / -f 3`

sshpass -p vagrant scp /home/jenkins/.dockercfg vagrant@${MASTER_IP}:~/

for f in ${IMG}; do
    sshpass  -p vagrant ssh vagrant@$MASTER_IP docker tag $f ${DOCKER_REGISTRY}/${IMAGES_NAMESPACE}/${f}:${DOCKER_TAG}
    sshpass  -p vagrant ssh vagrant@$MASTER_IP docker push ${DOCKER_REGISTRY}/${IMAGES_NAMESPACE}/${f}:${DOCKER_TAG}
done

dos.py erase ${ENV_NAME}

deactivate
