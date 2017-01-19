#!/bin/bash -ex

# Removes all fuel-devops deployment envs.


# CONFIGURATION:
######################################################
FUEL_DEVOPS_INSTALLATION_DIR="/home/jenkins/venv-fuel-devops-3.0"


source "${FUEL_DEVOPS_INSTALLATION_DIR}"/bin/activate
for f in `dos.py list | grep deployment`; do
    dos.py erase "${f}";
done
