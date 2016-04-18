#!/bin/bash
#
# Script for deploying OpenStack Kolla on top of Apache Mesos/Marathon cluster
# in custom configurations.
#
# If run inside CI, this script assumes kolla-all-kolla & kolla-all-kolla-mesos
# directories that contain kolla & kolla-mesos repositories.
#
# (c) mzawadzki@mirantis.com

# config:
###############################################################################
## docker:
export LC_ALL=en_US.UTF-8
###############################################################################

PRIMARY_ETH_IP=`ifconfig ${PRIMARY_ETH}  | grep 'inet addr:'| \
grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`
START_PWD=`pwd`

[[ ${-/x} != $- ]] && BASH_OPTION_X="-x"
[[ ${-/e} != $- ]] && BASH_OPTION_E="-e"

# Functions:
###############################################################################
function system-check {
    if [[ "`awk '/\/run / {print $7}' /proc/self/mountinfo`" =~ "shared*" ]]; then
        echo "Ensure 'sudo mount --make-shared /run' was run on this machine."
        echo "Aborting"
        exit 1
    fi
    if [ -z "`docker --version`" ]; then
        echo "No docker or no permissions."
        echo "Aborting"
        exit 1
    fi
    if ! `which pip > /dev/null 2>&1`; then
        echo "pip is missing, aborting."
        exit 1
    fi
    if ! `which virtualenv > /dev/null 2>&1`; then
        echo "virtualenv is missing, aborting."
        exit 1
    fi
    if [ -z "`pip list | grep docker-py`" ]; then
        echo "docker-py missing, aborting."
        exit 1
    fi
    if [ -z "`tox --version`" ]; then
        echo "tox missing, aborting."
        exit 1
    fi
    if [ -z "`ansible --version | grep 1.9`" ]; then
        echo "ansible 1.9.* missing, aborting."
        exit 1
    fi
    if [ -z "${JENKINS_HOME}" ] && [ -z "${GERRIT_USER}" ]; then
        echo "Seems like script is run outside of CI and no gerrit username"
        echo "was set (see --gerrit-user). Aborting."
        exit 1
    fi
    if [ -z "${DOCKER_IMAGE_TAG}" ] || [ "${DOCKER_IMAGE_TAG}" == "_" ]; then
        echo "Docker tag for images is not set (see --tag). Assuming 'latest'"
        DOCKER_IMAGE_TAG="latest"
    fi
}

function print-diagnostics {
    echo "-----------------------------------------------------"
    echo "Diagnostic info:"
    hostname
    date
    lsb_release  -a
    uname -a
    docker --version
    env | sort
    echo "Docker tag: "${DOCKER_IMAGE_TAG}
    echo "Primary IP: "${PRIMARY_ETH_IP}
    #git branch
    #git rev-parse HEAD
    #git status
    #git diff HEAD^
    pwd
    ls -alh
    echo "-----------------------------------------------------"
}

function docker-status {
    echo "* current status of Docker:"
    docker ps -a
    docker volume ls
}

function full-cleanup {
    echo "[WARNING] RUNNING CLEANUP:"
    docker-status
    echo "* stopping and removing mesos docker containers..."
    docker stop mesos_slave chronos marathon mesos_master zookeeper mesos-dns
    docker rm mesos_slave chronos marathon mesos_master zookeeper mesos-dns

    echo "* stopping and removing all kolla docker containers..."
    docker ps -a | grep kolla | awk '{system("docker stop -t 0 "$1)}'
    docker ps -a | grep kolla | awk '{system("docker rm -f "$1)}'

    echo "* removing kolla docker volumes..."
    docker volume ls | grep -e mariadb_kolla -e zookeeper_data \
    -e kolla_logs_kolla -e neutron_metadata_socket \
    | awk '{system("docker volume rm "$2)}'

    echo "* removing files in /tmp..."
    rm -rf /tmp/.ansible*

    #workaround to remove directories created by root
    #in some containers
    echo "* removing directories with root permissions "
    msl=`docker images | grep mesos-slave`
    sltag=`echo $msl | awk '{print $2}'`
    slim=`echo $msl | awk '{print $1}'`
    slave_image="$slim:$sltag"
    echo $slave_image
    docker run --rm -v /tmp:/tmp $slave_image rm -rf /tmp/mesos
    docker run --rm -v /tmp:/tmp $slave_image rm -rf /tmp/kolla*

    docker-status
}

function prepare-repos {
    cd ${START_PWD}
    if [ -z "${JENKINS_HOME}" ]; then
        echo "Seems like we run outside of CI."
        git clone ssh://${GERRIT_USER}@review.fuel-infra.org:29418/openstack/kolla kolla-all-kolla
        cd kolla-all-kolla
        git checkout mirantis
        cd ..
        git clone ssh://${GERRIT_USER}@review.fuel-infra.org:29418/openstack/kolla-mesos kolla-all-kolla-mesos
        cd kolla-all-kolla-mesos
        git checkout mirantis
        cd ..
    else
        echo "Seems like we run inside CI."
        if [ -z "${GERRIT_USER}" ]; then
            GERRIT_USER="nextgen-ci"
        fi
        if [ -n "${GERRIT_BRANCH}" ]; then
            echo "* seems like this is gerrit-triggered job, fetching the change."
            GERRIT_PROJECT_NAME="`echo ${GERRIT_PROJECT} | sed 's/openstack\///'`"
            cd kolla-all-${GERRIT_PROJECT_NAME}
            git fetch ssh://${GERRIT_USER}@review.fuel-infra.org:29418/${GERRIT_PROJECT} ${GERRIT_REFSPEC} && git checkout FETCH_HEAD
            cd ..
        else
            echo "* seems like this is manual-triggered job."
        fi
    fi

    # TODO(mzawadzki): hack, to be removed after 17648
    # (Use constraints only on multinode deployment) is merged.
    # cd kolla-all-kolla-mesos
    # git fetch ssh://${GERRIT_USER}@review.fuel-infra.org:29418/openstack/kolla-mesos refs/changes/48/17648/1 && git cherry-pick FETCH_HEAD
    # cd ..

    rm -rf repos
    mkdir repos
    cd repos
    mkdir mesos openstack

    cp -r ${START_PWD}/kolla-all-kolla mesos/kolla
    cp -r ${START_PWD}/kolla-all-kolla-mesos mesos/kolla-mesos
    cp -r ${START_PWD}/kolla-all-kolla openstack/kolla
    cp -r ${START_PWD}/kolla-all-kolla-mesos openstack/kolla-mesos
}


function deploy-mesos {
    cd ${START_PWD}/repos/mesos/kolla-mesos

    # Configure & install kolla-mesos:
    tox -e genconfig
    sed -i "s/network_interface: \"eth2\"/network_interface: \"${PRIMARY_ETH}\"/g" etc/globals.yml
    sed -i "s/docker_registry: \"operator.local:5000\"/docker_registry: \"${DOCKER_PRIVATE_REGISTRY}\"/g" etc/globals.yml
    sed -i "s/docker_namespace: \"kollaglue\"/docker_namespace: \"${DOCKER_PRIVATE_REGISTRY_NAMESPACE}\"/g" etc/globals.yml
    sed -i "s/openstack_release: \"2.0.0\"/openstack_release: \"${DOCKER_IMAGE_TAG}\"/g" etc/globals.yml
    sed -i 's/kolla_base_distro: "centos"/kolla_base_distro: "ubuntu"/g' etc/globals.yml
    sed -i 's/\/etc\/kolla/\/tmp\/kolla/g' ansible/group_vars/all.yml
    # Hack:
    #cp etc/passwords.yml /tmp
    #sed -i "s/file_utils.find_config_file('passwords.yml')/'\/tmp\/passwords.yml'/g" kolla_mesos/cmd/deploy.py
    PWD_ESCAPED="`pwd |sed -e 's:/:\\\/:g'`"
    sed -i "s/\/usr\/local\/share\/kolla-mesos/${PWD_ESCAPED}/g" kolla_mesos/common/file_utils.py
    virtualenv venv
    source venv/bin/activate
    pip install --upgrade .

    # Deploy Mesos services in containers:
    docker stop mesos_slave chronos marathon mesos_master zookeeper mesos-dns || true
    docker rm mesos_slave chronos marathon mesos_master zookeeper mesos-dns || true
    # note: ensure no DNS servers are running on your machine (e.g. dnsmasq)
    # prior to mesos-dns:
    if [ -n "`netstat -nlt | grep ':53'`" ]; then
        echo "Port 53 is already in use, mesos-dns won't be able to start, aborting."
        netstat -pnlt | grep 53
    exit 1
    fi
    KOLLA_MESOS_ANSIBLE_EXTRA_OPTIONS=""
    if ${AIO}; then
        KOLLA_MESOS_ANSIBLE_EXTRA_OPTIONS="--aio"
    fi
    kolla-mesos-ansible deploy ${KOLLA_MESOS_ANSIBLE_EXTRA_OPTIONS} --config-dir etc/
    docker ps | grep ${DOCKER_IMAGE_TAG} | grep -e mesos  -e marathon -e zookeeper -e chronos
    # verify web UIs for Mesos & Marathon are accessible & Mesos slave is connected:
    # http://172.20.9.25:5050
    # http://172.20.9.25:8080
    deactivate
}

function configure-and-install-kolla-mesos {
    cd ${START_PWD}/repos/openstack/kolla-mesos

    # Configure & install kolla-mesos:
    tox -e genconfig
    # set these accordingly to repo, namespace and tag:
    sed -i "s/docker_registry: \"operator.local:5000\"/docker_registry: \"${DOCKER_PRIVATE_REGISTRY}\"/g" etc/globals.yml
    sed -i "s/docker_namespace: \"kollaglue\"/docker_namespace: \"${DOCKER_PRIVATE_REGISTRY_NAMESPACE}\"/g" etc/globals.yml
    # use tag "latest" for latest images from mirantis branch
    # or "mirantis_CR" (e.g. "mirantis_17317") for images built for change request
    sed -i "s/openstack_release: \"2.0.0\"/openstack_release: \"${DOCKER_IMAGE_TAG}\"/g" etc/globals.yml
    sed -i 's/kolla_base_distro: "centos"/kolla_base_distro: "ubuntu"/g' etc/globals.yml
    # set this accordingly to primary public network interface:
    sed -i "s/kolla_internal_address: \"10.10.10.254\"/kolla_internal_address: \"${PRIMARY_ETH_IP}\"/g" etc/globals.yml
    sed -i "s/network_interface: \"eth2\"/network_interface: \"${PRIMARY_ETH}\"/g" etc/globals.yml
    sed -i "s/neutron_external_interface: \"eth2\"/neutron_external_interface: \"${SECONDARY_ETH}\"/g" etc/globals.yml
    sed -i 's/enable_horizon: "no"/enable_horizon: "yes"/g' etc/globals.yml
    sed -i 's/enable_memcached: "no"/enable_memcached: "yes"/g' etc/globals.yml
    cp etc/kolla-mesos.conf.sample etc/kolla-mesos.conf
    # set this accordingly to primary public network interface:
    sed -i -e "s/#host = http:\/\/127.0.0.1/host = http:\/\/${PRIMARY_ETH_IP}/g" -e "s/#host = 127.0.0.1/host = ${PRIMARY_ETH_IP}/g" etc/kolla-mesos.conf
    sed -i -e "s/#private_interface = eth1/private_interface = ${PRIMARY_ETH}/g" -e "s/#public_interface = eth2/public_interface = ${PRIMARY_ETH}/g" etc/kolla-mesos.conf
    # (verify manually that all entries got set correctly)
    cat etc/globals.yml
    grep host etc/kolla-mesos.conf
    grep _interface etc/kolla-mesos.conf
    # set resources:
    sed -i "s/default('128')/default('1024')/g" config/keystone/defaults/main.yml
    sed -i "s/default('0.3')/default('1.0')/g" config/keystone/defaults/main.yml
    sed -i "s/default('128')/default('1024')/g" config/horizon/defaults/main.yml
    sed -i "s/default('0.3')/default('1.0')/g" config/horizon/defaults/main.yml
    sed -i "s/default('128')/default('1024')/g" config/mariadb/defaults/main.yml
    sed -i "s/default('0.3')/default('1.0')/g" config/mariadb/defaults/main.yml
    sed -i "s/default('128')/default('1024')/g" config/memcached/defaults/main.yml
    sed -i "s/default('0.3')/default('1.0')/g" config/memcached/defaults/main.yml
    sed -i "s/default('128')/default('1024')/g" config/rabbitmq/defaults/main.yml
    sed -i "s/default('0.3')/default('1.0')/g" config/rabbitmq/defaults/main.yml
    # set marathon_framework (autodetect doesn't work)
    sed -i 's/# marathon_framework: "marathon"/marathon_framework: "marathon"/g' etc/globals.yml
    # set correct mesos domain name:
    sed -i 's/mesos_dns_domain: "kolla-team-env.local"/mesos_dns_domain: "mesos"/g' etc/globals.yml
    #cp etc/passwords.yml /tmp
    #sed -i "s/file_utils.find_config_file('passwords.yml')/'\/tmp\/passwords.yml'/g" kolla_mesos/cmd/deploy.py
    #cp etc/globals.yml /tmp
    #sed -i "s/file_utils.find_config_file('globals.yml')/'\/tmp\/globals.yml'/g" kolla_mesos/cmd/deploy.py
    PWD_ESCAPED="`pwd |sed -e 's:/:\\\/:g'`"
    sed -i "s/self.base_dir = os.path.abspath(file_utils.find_base_dir())/self.base_dir = '${PWD_ESCAPED}'/g" kolla_mesos/service.py
    sed -i "s/\/usr\/local\/share\/kolla-mesos/${PWD_ESCAPED}/g" kolla_mesos/common/file_utils.py
    sed -i "s/\/etc\/kolla-mesos/etc/g" kolla_mesos/common/file_utils.py

    virtualenv venv
    source venv/bin/activate
    # make sure "nameserver 172.20.9.25" is the first nameserver entry in /etc/resolv.conf on your host
    cat /etc/resolv.conf
    pip install --upgrade .

    cd ${START_PWD}/repos/openstack/kolla
    pip install --upgrade .
    which kolla-build
    which kolla-mesos-cleanup
    which kolla-mesos-deploy
}

function deploy-kolla-on-mesos {
    cd ${START_PWD}/repos/openstack/kolla-mesos
    # 2.4. Deploy Kolla OpenStack on Mesos:
    docker rm $(docker ps -a | grep Exited | awk '{print $1}') || true
    cd ${START_PWD}/repos/openstack/kolla-mesos
    source venv/bin/activate
    kolla-mesos --config-dir etc/ deployment cleanup
    kolla-mesos --config-dir etc/ deployment run
    sleep 10
    while [ -n "`docker ps | grep -i toolbox`" ]; do
        echo "Waiting for all toolbox containers to finish..."
        sleep 5
    done
    # verify OpenStack is working:
    pip install --upgrade pbr
    pip install --upgrade python-openstackclient
    which openstack
    openstack --version
    source ./openrc
    openstack user list
    # navigate to: http://172.20.9.25
    deactivate
}
###############################################################################

# Run:

print-diagnostics
system-check

if ${FULL_CLEANUP}; then
    full-cleanup || true
fi

prepare-repos

if ! ${OPENSTACK_ONLY}; then
    if ${AIO}; then
        echo "Preparing AIO Mesos cluster."
        deploy-mesos
        if ${INFRA_ONLY}; then
            exit
        fi
    fi
fi

if ! ${INFRA_ONLY}; then
    echo "Configuring and installing kolla-mesos:"
    configure-and-install-kolla-mesos
    echo "Deploying Kolla OpenStack on Mesos cluster:"
    deploy-kolla-on-mesos
    if ${OPENSTACK_ONLY}; then
        exit
    fi
fi
