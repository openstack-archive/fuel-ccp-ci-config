#!/bin/bash -ex

# Removes snapshots of fuel-devops envs.


# CONFIGURATION:
######################################################
FUEL_DEVOPS_INSTALLATION_DIR="/home/jenkins/venv-fuel-devops-3.0"
: ${FUEL_DEVOPS_ENV_NAME:="ccp-simple-deployment-env"}
: ${FUEL_SNAPSHOT_NAME:="fresh"}


source "${FUEL_DEVOPS_INSTALLATION_DIR}"/bin/activate
dos.py snapshot-delete "${FUEL_DEVOPS_ENV_NAME}" "${FUEL_SNAPSHOT_NAME}"
