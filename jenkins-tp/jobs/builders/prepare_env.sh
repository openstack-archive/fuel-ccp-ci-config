#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

ACT=0

function update_devops {
    ACT=1
    VIRTUAL_ENV=/home/jenkins/venv-fuel-devops${1}
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

    # Upgrade pip inside virtualenv
    pip install pip --upgrade

    if [[ -n "${VENV_REQUIREMENTS}" ]]; then
        echo "Install with custom requirements"
        echo "${VENV_REQUIREMENTS}" >"${WORKSPACE}/venv-requirements.txt"
        pip install -r "${WORKSPACE}/venv-requirements.txt" --upgrade
    fi

    pip install git+git://git.openstack.org/openstack/fuel-devops@3.0.1 --upgrade

    echo "=============================="
    pip freeze
    echo "=============================="
    django-admin.py syncdb --settings=devops.settings --noinput
    django-admin.py migrate devops --settings=devops.settings --noinput
    deactivate

}

function download_images {
    ACT=1
    TARGET_CLOUD_DIR=/home/jenkins/workspace/cloud-images
    VM_IMAGE="http://share01-scc.ng.mirantis.net/packer-ubuntu-1604-server-new.qcow2"
    mkdir -p ${TARGET_CLOUD_DIR}
    pushd ${TARGET_CLOUD_DIR}
    wget ${VM_IMAGE}
    popd
}

function install_zuul_env {
    VIRTUAL_ENV=/home/jenkins/venv-zuul
    if [ -f ${VIRTUAL_ENV}/bin/activate ]; then
        source ${VIRTUAL_ENV}/bin/activate
        echo "Python virtual env exist"
    else
        rm -rf ${VIRTUAL_ENV}
        virtualenv --no-site-packages  ${VIRTUAL_ENV}
        source ${VIRTUAL_ENV}/bin/activate
    fi

    # Upgrade pip inside virtualenv
    pip install pip --upgrade

    pip install zuul
}


 DevOps 3.0.x
if [[ ${update_devops_3_0_x} == "true" ]]; then
    update_devops "-3.0" "fuel-ccp-tests" "master"
fi

if [[ ${download_images} == "true" ]]; then
    download_images
fi

if [[ ${install_zuul} == "true" ]]; then
    install_zuul_env
fi

if [ ${ACT} -eq 0 ]; then
    echo "No action selected!"
    exit 1
fi
