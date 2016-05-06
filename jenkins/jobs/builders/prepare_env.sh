#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

ACT=0

function update_devops () {
  ACT=1
  VIRTUAL_ENV=/home/jenkins/venv-nailgun-tests${1}
  REPO_NAME=${2}
  BRANCH=${3}

  if [[ -d "${VIRTUAL_ENV}" ]] && [[ "${FORCE_DELETE_DEVOPS}" == "true" ]]; then
    echo "Delete venv from ${VIRTUAL_ENV}"
    rm -rf ${VIRTUAL_ENV}
  fi

  if [ -f ${VIRTUAL_ENV}/bin/activate ]; then
    source ${VIRTUAL_ENV}/bin/activate
    echo "Python virtual env exist"
  else
    rm -rf ${VIRTUAL_ENV}
    virtualenv --no-site-packages  ${VIRTUAL_ENV}
    source ${VIRTUAL_ENV}/bin/activate
  fi

  #
  # fuel-devops use ~/.devops directory to store log configuration
  # we need to delete log.yaml befeore update to get it in current
  # version
  #
  test -f ~/.devops/log.yaml && rm ~/.devops/log.yaml

  # Prepare requirements file
  if [[ -n "${VENV_REQUIREMENTS}" ]]; then
    echo "Install with custom requirements"
    echo "${VENV_REQUIREMENTS}" >"${WORKSPACE}/venv-requirements.txt"
  else
    if ! curl -fsS "https://raw.githubusercontent.com/openstack/${REPO_NAME}/${BRANCH}/fuelweb_test/requirements.txt" > "${WORKSPACE}/venv-requirements.txt"; then
      echo "Problem with downloading requirements"
      exit 1
    fi
  fi

  # Upgrade pip inside virtualenv
  pip install pip --upgrade

  pip install -r "${WORKSPACE}/venv-requirements.txt" --upgrade
  echo "=============================="
  pip freeze
  echo "=============================="
  django-admin.py syncdb --settings=devops.settings --noinput
  django-admin.py migrate devops --settings=devops.settings --noinput
  deactivate

}

function download_images () {
  ACT=1
  TARGET_CLOUD_DIR=/home/jenkins/workspace/cloud-images
  mkdir -p ${TARGET_CLOUD_DIR}
}

# DevOps 2.5.x
if [[ ${update_devops_2_5_x} == "true" ]]; then
  update_devops "" "fuel-main" "stable/6.1"
fi

# DevOps 2.9.x
if [[ ${update_devops_2_9_x} == "true" ]]; then
  update_devops "-2.9" "fuel-qa" "master"
fi

if [[ ${download_images} == "true" ]]; then
  download_images
fi

if [ ${ACT} -eq 0 ]; then
  echo "No action selected!"
  exit 1
fi
