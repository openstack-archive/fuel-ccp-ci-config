#!/bin/bash

set -ex

if [[ -z ${IMAGE_PATH} ]]; then
  echo "The IMAGE_PATH variable is not set!"
  exit -1
fi

#if [[ ! -e ${IMAGE_PATH} ]]; then
#  echo "The image was not found. Need to download it..."
#  if [[ ! -z ${HTTP_LINK} ]]; then
#    curl ${HTTP_LINK} -O ${IMAGE_PATH}
#  else
#    echo "Unable to download the image! HTTP_LINK is not set."
#    exit -1
#  fi
#fi


echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

TEST_IMAGE_JOB_URL="${JENKINS_URL}job/0.1-mcp.test_all/"

virtualenv $WORKSPACE/venv-fuel-ccp-tests
cd fuel-ccp-tests
pip install -U .
cd ..
export ENV_PREFIX="fuel-ccp-tests"

source $WORKSPACE/venv-fuel-ccp-tests/bin/activate

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
ENV_NAME=${ENV_NAME:0:68}
export ENV_NAME=${ENV_NAME}
export IMAGE_PATH=${IMAGE_PATH}
export WORKSPACE=${WORKSPACE}
export BUILD_IMAGES=True
export DEPLOY_SCRIPT=${WORKSPACE}/fuel-ccp-installer/utils/jenkins/kargo_deploy.sh
export CONF_PATH="fuel_ccp_tests/templates/default.yaml"
export IMAGES_NAMESPACE='mcp'

echo "----==== RUN TEST ====----"
cd fuel-ccp-tests

py.test -vvv -s  fuel_ccp_tests/tests/system/test_deploy.py::TestDeployOpenstack::test_fuel_ccp_deploy_microservices
deactivate
