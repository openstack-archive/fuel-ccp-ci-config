#!/bin/bash

set -ex

export ENV_NAME="solar-k8s-env-$BUILD_NUMBER.$BUILD_ID"

source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
echo "Running on $NODE_NAME: $ENV_NAME"

dos.py erase ${ENV_NAME}
deactivate

