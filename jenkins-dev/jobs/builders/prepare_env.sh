#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

function update_devops () {
    local VIRTUAL_ENV="/home/jenkins/venv-nailgun-tests${1}"
    local REPO_NAME="${2}"
    local BRANCH="${3}"

    if [[ -d "${VIRTUAL_ENV}" ]] && [[ "${FORCE_DELETE_DEVOPS}" == "true" ]]; then
        echo "Delete venv from ${VIRTUAL_ENV}"
        rm -rf "${VIRTUAL_ENV}"
    fi

    if [[ -f "${VIRTUAL_ENV}/bin/activate" ]]; then
        echo "Python virtual env exist"
    else
        rm -rf "${VIRTUAL_ENV}"
        virtualenv --no-site-packages "${VIRTUAL_ENV}"
    fi
    source "${VIRTUAL_ENV}/bin/activate"

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
        local REQUIREMENTS_URL="https://raw.githubusercontent.com/openstack/${REPO_NAME}/${BRANCH}/fuelweb_test/requirements.txt"
        if ! curl -fsS "${REQUIREMENTS_URL}" > "${WORKSPACE}/venv-requirements.txt"; then
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
    local TARGET_CLOUD_DIR=/home/jenkins/workspace/cloud-images
    mkdir -p ${TARGET_CLOUD_DIR}

    for IMAGE in "${CLOUD_FEDORA}" \
                 "${SAVANNA_IMAGE}" \
                 "${F17_IMAGE}" \
                 "${MURANO_IMAGE}" \
                 "${MURANO_IMAGE_26_02_15}" \
                 "${SAHARA_JUNO_HDP}" \
                 "${SAHARA_JUNO_VANILLA}" \
                 "${SAHARA_KILO_VANILLA}" \
                 "${SAHARA_LIBERTY_VANILLA}" \
                 "${QA_CENTOS_COMPUTE}" \
                 "${QA_CENTOS_CLOUD}" \
                 "${QA_RHEL_COMPUTE}" \
                 "${QA_OL_COMPUTE}" \
                 "${INSTALL_PACKAGES_CENTOS_6_4}" \
                 "${INSTALL_PACKAGES_CENTOS_7_0}" \
                 "${INSTALL_PACKAGES_UBUNTU_12_04}" \
                 "${INSTALL_PACKAGES_UBUNTU_14_04}";
    do
        seedclient.py -d -m "${IMAGE}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}"
    done
}

ACT=
# DevOps 2.5.x
if [[ ${update_devops_2_5_x} == "true" ]]; then
    update_devops "" "fuel-main" "stable/6.1"
    ACT=1
fi

# DevOps 2.9.x
if [[ ${update_devops_2_9_x} == "true" ]]; then
    update_devops "-2.9" "fuel-qa" "master"
    ACT=1
fi

if [[ ${download_images} == "true" ]]; then
    download_images
    ACT=1
fi

if [[ -z "${ACT}" ]]; then
    echo "No action selected!"
    exit 1
fi
