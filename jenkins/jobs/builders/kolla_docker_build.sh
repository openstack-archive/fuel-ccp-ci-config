#!/bin/bash
#
# Script for building Kolla Docker images with Jenkins.
# arguments: --build-all (optional, build all images only, default: false)
#
# (c) mzawadzki@mirantis.com

set +x

###############################################################################
# config:
DOCKER_PRIVATE_REGISTRY_PRIMARY="registry01-scc.fuel-infra.org"
DOCKER_PRIVATE_REGISTRY_SECONDARY="registry01-bud.fuel-infra.org"
DOCKER_PRIVATE_REGISTRY_USERNAME="nextgen"
DOCKER_PRIVATE_REGISTRY_EMAIL="kolla@mirantis.com"
DOCKER_PRIVATE_REGISTRY_PASSWORD="ti5Eeng3"
DOCKER_PRIVATE_REGISTRY_USERNAME="nextgen"
DOCKER_PRIVATE_REGISTRY_NAMESPACE="nextgen"
DOCKER_IMAGE_TAG="${GERRIT_BRANCH}_${GERRIT_CHANGE_NUMBER}"
KOLLA_IMAGES_TO_BUILD="chronos,marathon,mesos-master,mesos-slave,\
mesos-dns,zookeeper,kolla-toolbox,glance,horizon,keystone,mariadb,\
memcached,neutron,nova,rabbitmq"
NUMBER_OF_THREADS=6
# TODO(mzawadzki): implement scenario where 1 OpenStack service
# has multiple Docker images.
COMMAND_TO_LIST_CHANGED_FILES="git diff-tree --no-commit-id --name-only \
-r HEAD"
# COMMAND_TO_LIST_CHANGED_FILES="echo -e docker/ironic/test\ndocker/nova/test\
# \ntest\ndocker/horizon/test2/test"  #test

###############################################################################
# Functions:
function push_docker_images {
    set -x
    DOCKER_REGISTRY=$1

    docker login -u ${DOCKER_PRIVATE_REGISTRY_USERNAME} \
    -e ${DOCKER_PRIVATE_REGISTRY_EMAIL} \
    -p ${DOCKER_PRIVATE_REGISTRY_PASSWORD} ${DOCKER_REGISTRY}
    docker images | grep kollaglue | grep ${DOCKER_IMAGE_TAG} | \
    awk -v reg=${DOCKER_REGISTRY} \
    -v ns=${DOCKER_PRIVATE_REGISTRY_NAMESPACE} -v tag=${DOCKER_IMAGE_TAG} '
        function basename(path) {
            sub(".*/", "", path)
            return path
        }
        {
            print "* tagging "$3" to "reg"/"ns"/"basename($1)":"tag
            system("docker tag "$3" "reg"/"ns"/"basename($1)":"tag);
            system("docker push "reg"/"ns"/"basename($1)":"tag);
        }
    '
    set +x
}

function print_diagnostics {
    echo "-----------------------------------------------------"
    echo "** Diagnostic info:"
    set -x
    hostname
    date
    lsb_release  -a
    uname -a
    docker --version
    env
    git branch
    git status
    pwd
    ls -alh
    set +x
}

function install_and_configure_kolla {
    echo "-----------------------------------------------------"
    echo "** Setting up Kolla in virtual environment, "
    echo "modyfing config and repos:"
    set -x
    sed -i "s/archive.ubuntu.com/us3.archive.ubuntu.com/g" \
    docker/base/sources.list
    grep 'archive.ubuntu.com' docker/base/sources.list
    sed -i "s/mirror.fuel-infra.org/mirror.seed-us1.fuel-infra.org/g" \
    docker/base/sources.list
    grep 'fuel-infra.org' docker/base/sources.list
    virtualenv kolla_venv
    source kolla_venv/bin/activate
    pip install tox
    pip install .
    hash -r
    which kolla-build
    tox --version
    tox -e genconfig
    sed -i "s/\#default =.*/default = ${KOLLA_IMAGES_TO_BUILD}/g" \
    etc/kolla/kolla-build.conf
    grep 'default =' etc/kolla/kolla-build.conf
    set +x
}

function build_kolla {
    echo "-----------------------------------------------------"
    echo "** Building Kolla:"
    set -x
    # FIXME(mzawadzki): +e should not be used, it should be fixed properly,
    # see # https://review.fuel-infra.org/#/c/16871/
    set +e
    kolla-build --profile default --config-dir etc/kolla/ \
    -b ubuntu -t binary \
    --tag ${DOCKER_IMAGE_TAG}
    se -e
    set +x
# commented out code for building just specific images:
#    for f in `${COMMAND_TO_LIST_CHANGED_FILES} | \
#    sed -nr 's/^docker\/([a-z]+).*/\1/p'`
#    do
#        echo "*"${f}":"
#        set -x
#        set +e
#        kolla-build --registry ${DOCKER_PRIVATE_REGISTRY_PRIMARY} \
#        --namespace ${DOCKER_PRIVATE_REGISTRY_NAMESPACE} \
#        --tag ${DOCKER_IMAGE_TAG} \
#        --push -b ubuntu -t binary ${f}
#        set -e
#        set +x
#    done
}

function print_report {
    echo "-----------------------------------------------------"
    echo "** Local cache: all images for this change request:"
    set -x
    docker images | grep ${DOCKER_IMAGE_TAG}
    set +x
    echo -e "\n** Remote registry: all images for this change request:"
    set -x
    curl -s "http://${DOCKER_PRIVATE_REGISTRY_PRIMARY}:5002\
    ?name=${DOCKER_PRIVATE_REGISTRY_NAMESPACE}\
    &tag=${DOCKER_IMAGE_TAG}&format=dictionary"
    echo -e "\n"
    curl -s "http://${DOCKER_PRIVATE_REGISTRY_SECONDARY}:5002\
    ?name=${DOCKER_PRIVATE_REGISTRY_NAMESPACE}\
    &tag=${DOCKER_IMAGE_TAG}&format=dictionary"
    set +x
    cat <<EOM
    -----------------------------------------------------
    ** Build finished.
    How to use your images:

    1) If you want to pull them with kolla-mesos-deploy:

    Set these lines in kolla-mesos global.yaml:
    docker_registry: "${DOCKER_PRIVATE_REGISTRY_PRIMARY}"
    # or:
    docker_registry: "${DOCKER_PRIVATE_REGISTRY_SECONDARY}"

    docker_namespace: "${DOCKER_PRIVATE_REGISTRY_NAMESPACE}"
    openstack_release: "${DOCKER_IMAGE_TAG}
    kolla_base_distro: "ubuntu"
    network_interface: "NAME" # (where NAME is e.g. eth0 or p1p1)

    And run kolla-mesos-deploy.


    2) If you want to pull them manually to local cache:

EOM
    for DOCKER_PRIVATE_REGISTRY in ${DOCKER_PRIVATE_REGISTRY_PRIMARY} \
    ${DOCKER_PRIVATE_REGISTRY_SECONDARY}
    do
        printf "docker pull ${DOCKER_PRIVATE_REGISTRY}/" \
        "${DOCKER_PRIVATE_REGISTRY_NAMESPACE}/" \
        "NAME_OF_THE_IMAGE:${DOCKER_IMAGE_TAG}"
        echo -e "\nin this case this will be:\n"
        printf -v DOCKER_REGISTRY_QUERY "%s%s%s" \
        "http://${DOCKER_PRIVATE_REGISTRY}:5002" \
        "?name=${DOCKER_PRIVATE_REGISTRY_NAMESPACE}" \
        "&tag=${DOCKER_IMAGE_TAG}&format=dictionary"
        echo "--copy/paste--"
        curl -s $DOCKER_REGISTRY_QUERY | \
        sed -e 's/ //g' -e "s/u'//g" -e "s/[{}']//g" -e 's/\[//g' -e 's/\]//g' \
        -e 's/,/\n/g' | \
        awk -v reg=${DOCKER_PRIVATE_REGISTRY} \
        -v ns=${DOCKER_PRIVATE_REGISTRY_NAMESPACE} \
        -v tag=${DOCKER_IMAGE_TAG} -F\: '
            function basename(path) {
                sub(".*/", "", path)
                return path
            }
            {
                print "docker pull "reg"/"ns"/"basename($1)":"$2
            }
        '
        echo "--copy/paste--"
        echo -e "\n"
    done
    cat <<EOM
    Note: for some builds (CI jobs) images are only pushed to 1 registry.
    -----------------------------------------------------

EOM
}


###############################################################################
# Code:
print_diagnostics
install_and_configure_kolla

if [ ${BUILD_ALL} == "true" ]; then
    DOCKER_IMAGE_TAG="latest"
else
    echo -e "\nlist of file affected by change-request:"
    ${COMMAND_TO_LIST_CHANGED_FILES}
    echo "-----------------------------------------------------"
    echo "** Rebuilding Docker images for affected components:"
    echo "** (rebuilding ALL in fact, to be optimized in the future...)"
fi
time build_kolla

echo "-----------------------------------------------------"
echo "** Pushing images to the primary & secondary Docker registry:"
time push_docker_images ${DOCKER_PRIVATE_REGISTRY_PRIMARY}
time push_docker_images ${DOCKER_PRIVATE_REGISTRY_SECONDARY}

print_report
