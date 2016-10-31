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

    # Change CPU mode (disable host-passthrough):
    cat > /tmp/fuel-devops_change_cpu_mode.patch << EOF
---
 devops/templates/default.yaml | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/devops/templates/default.yaml b/devops/templates/default.yaml
index aac4566..48d1a5a 100644
--- a/devops/templates/default.yaml
+++ b/devops/templates/default.yaml
@@ -86,7 +86,7 @@ template:
            storage_pool_name: !os_env STORAGE_POOL_NAME, default
            stp: True
            hpet: False
-           use_host_cpu: !os_env DRIVER_USE_HOST_CPU, true
+           use_host_cpu: false
 
        network_pools:  # Address pools for OpenStack networks.
          # Actual names should be used for keys
-- 
1.9.1
EOF
    git clone https://github.com/openstack/fuel-devops.git
    pushd fuel-devops
    git checkout tags/3.0.3
    git apply /tmp/fuel-devops_change_cpu_mode.patch
    pip install . --upgrade
    popd
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

# DevOps 3.0.x
if [[ ${update_devops_3_0_x} == "true" ]]; then
    update_devops "-3.0" "fuel-ccp-tests" "master"
fi

if [[ ${download_images} == "true" ]]; then
    download_images
fi

if [ ${ACT} -eq 0 ]; then
    echo "No action selected!"
    exit 1
fi
