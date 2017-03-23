#!/bin/bash -ex

# Deploys CCP and runs simple, built-in OpenStack tests.
# Kubernetes cluster is expected to be pre-deployed and snapshoted - if not
# this script will ensure this.
# The script expects fuel-ccp cloned into fuel-ccp/ and fuel-ccp-installer
# cloned into fuel-ccp-installer/ directory (e.g. by Jenkins SCM plugin).

# CONFIGURATION:
######################################################
: ${FUEL_DEVOPS_ENV_NAME:="fuel-ccp-${COMPONENT}-${VERSION}-deployment"}
FUEL_DEVOPS_SNAPSHOT_NAME="fresh"
FUEL_DEVOPS_INSTALLATION_DIR="/home/jenkins/venv-fuel-devops-3.0"
HYPERKUBE_REPO="quay.io/coreos/hyperkube"
HYPERKUBE_TAG="v1.5.1_coreos.0"
HYPERKUBE_VERSION="v1.5.1"
export APT_CACHE_SERVER_IP="`getent hosts cache-scc.ng.mirantis.net| awk '{print $1}'`"
export APT_CACHE_SERVER_PORT="3142"
export REGISTRY_IP=`ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`
export REGISTRY_PORT=5000
JENKINS_GID=`getent group jenkins | cut -d":" -f3`
REGISTRY_HASH=`docker inspect --format "{{.Id}}" registry`
export DOCKER_REGISTRY_HOST="registry.mcp.fuel-infra.org"
export DOCKER_REGISTRY="${DOCKER_REGISTRY_HOST}:6000"
export DOCKER_REGISTRY_IP="`getent hosts ${DOCKER_REGISTRY_HOST} | awk '{print $1}'`"
export IMAGES_NAMESPACE="ccp"
export REGISTRY_NAMESPACE="mcp"
export SHARE_IP="`getent hosts share01-scc.ng.mirantis.net | awk '{print $1}'`"

function prepare_k8s_env {
    # Prepare K8s env:
    source "${FUEL_DEVOPS_INSTALLATION_DIR}"/bin/activate
    NEED_TO_SETUP_ENV=false
    dos.py revert "${FUEL_DEVOPS_ENV_NAME}" "${FUEL_DEVOPS_SNAPSHOT_NAME}" || NEED_TO_SETUP_ENV=true
    dos.py resume "${FUEL_DEVOPS_ENV_NAME}" || NEED_TO_SETUP_ENV=true
    if [ "${NEED_TO_SETUP_ENV}" = "true" ]; then
        echo "Couldn't revert fuel-devops snapshot, recreating environment."

        # Try to delete old envs to ensure clean host:
        dos.py destroy "${FUEL_DEVOPS_ENV_NAME}" || true
        dos.py erase "${FUEL_DEVOPS_ENV_NAME}" || true

        # Create kargo deployment script:
        cat > k8s_deploy.sh << EOF
#!/bin/bash -ex

export ENV_NAME=${FUEL_DEVOPS_ENV_NAME}
export IMAGE_PATH="/home/jenkins/workspace/cloud-images/default-image.qcow2"
export DONT_DESTROY_ON_SUCCESS=1
export DEPLOY_METHOD="kargo"
export SLAVES_COUNT="3"
export ADMIN_NODE_CPU=5
export ADMIN_NODE_MEMORY=14336
export SLAVE_NODE_CPU=3
export SLAVE_NODE_MEMORY=8192
export WORKSPACE="/home/jenkins/workspace"
export FUEL_DEVOPS_INSTALLATION_DIR=${FUEL_DEVOPS_INSTALLATION_DIR}
export CUSTOM_YAML='hyperkube_image_repo: "${HYPERKUBE_REPO}"
hyperkube_image_tag: "${HYPERKUBE_TAG}"
kube_version: "${HYPERKUBE_VERSION}"
docker_options: "--insecure-registry=${REGISTRY_IP}:${REGISTRY_PORT} --insecure-registry=DOCKER_REGISTRY"'
echo "Running on \${NODE_NAME}: \${ENV_NAME}"
source \${FUEL_DEVOPS_INSTALLATION_DIR}/bin/activate
echo "Use image:"
ls -la \${IMAGE_PATH}
env
pushd fuel-ccp-installer
bash -ex "./utils/jenkins/run_k8s_deploy_test.sh"
popd
EOF
        chmod +x k8s_deploy.sh

        # Now deploy the cluster:
        ./k8s_deploy.sh

        # Create fresh snapshot:
        dos.py suspend "${FUEL_DEVOPS_ENV_NAME}"
        dos.py snapshot "${FUEL_DEVOPS_ENV_NAME}" "${FUEL_DEVOPS_SNAPSHOT_NAME}"

        # Resume from snapshot to deploy CCP later on in the script:
        dos.py resume "${FUEL_DEVOPS_ENV_NAME}"
    fi
}


function fix_restored_env {

    # After restore snapshot ntp service doesn't work and need restart on all nodes
    ${SSH_COMMAND} "sudo service ntp restart"
    ${SSH_COMMAND} "ssh -o StrictHostKeyChecking=no node2 sudo service ntp restart"
    ${SSH_COMMAND} "ssh -o StrictHostKeyChecking=no node3 sudo service ntp restart"


    # Dirty hack for workaround network problems on CI envs.
    # When we deploy env some time after (few minutes) it change resolv.conf into broken one
    # From this reason after bring up env we restart network and and kill dhclient,
    # we also restart docker and kubelet to make sure that all net-host containers are in good shape

    cat > fix_dns.sh << EOF
    sudo service networking restart
    sudo pkill -9 dhclient
    sudo service kubelet restart
    sudo service docker restart
EOF

    chmod +x fix_dns.sh

    ${SCP_COMMAND} fix_dns.sh vagrant@"${ADMIN_IP}":~/
    ${SSH_COMMAND} "scp -o StrictHostKeyChecking=no fix_dns.sh vagrant@node2:~/"
    ${SSH_COMMAND} "scp -o StrictHostKeyChecking=no fix_dns.sh vagrant@node3:~/"
    ${SSH_COMMAND} "sudo ./fix_dns.sh"
    ${SSH_COMMAND} "ssh -o StrictHostKeyChecking=no node2 sudo ./fix_dns.sh"
    ${SSH_COMMAND} "ssh -o StrictHostKeyChecking=no node3 sudo ./fix_dns.sh"

}

function copy_code_to_vm {
    # Prepare env on "admin" VM:
    if [ ${COMPONENT} == "full" ]; then
        ${SCP_COMMAND} -r fuel-ccp/ vagrant@"${ADMIN_IP}":~/
    elif [ ${COMPONENT} == "smoke" ]; then
        ${SCP_COMMAND} -r fuel-ccp/ vagrant@"${ADMIN_IP}":~/
    else
        ${SCP_COMMAND} -r fuel-ccp/ vagrant@"${ADMIN_IP}":~/
        # set +x is just for security reasons to avoid publishing internal IP
        set +x
        getent hosts zuul.mcp.fuel-infra.org | ${SSH_COMMAND} "sudo tee -a /etc/hosts"
        set -x
        ${SCP_COMMAND} -r containers/openstack/ vagrant@"${ADMIN_IP}":/tmp/ccp-repos
    fi
}


function prepare_ccp_config {
cat > ccp.yml << EOF
builder:
  push: True
  workers: 1
registry:
  address: "${REGISTRY_IP}:${REGISTRY_PORT}"
  timeout: 1500
replicas:
  etcd: 3
  database: 3
  rpc: 3
  notifications: 1
repositories:
  path: /tmp/ccp-repos
  skip_empty: True
  entrypoint_repo_name: entrypoint
  repos:
    - git_url: https://git.openstack.org/openstack/fuel-ccp-debian-base
      name: debian-base
    - git_url: https://git.openstack.org/openstack/fuel-ccp-entrypoint
      name: entrypoint
    - git_url: https://git.openstack.org/openstack/fuel-ccp-etcd
      name: etcd
    - git_url: https://git.openstack.org/openstack/fuel-ccp-galera
      name: galera
    - git_url: https://git.openstack.org/openstack/fuel-ccp-glance
      name: glance
    - git_url: https://git.openstack.org/openstack/fuel-ccp-heat
      name: heat
    - git_url: https://git.openstack.org/openstack/fuel-ccp-horizon
      name: horizon
    - git_url: https://git.openstack.org/openstack/fuel-ccp-keystone
      name: keystone
    - git_url: https://git.openstack.org/openstack/fuel-ccp-memcached
      name: memcached
    - git_url: https://git.openstack.org/openstack/fuel-ccp-neutron
      name: neutron
    - git_url: https://git.openstack.org/openstack/fuel-ccp-nova
      name: nova
    - git_url: https://git.openstack.org/openstack/fuel-ccp-nginx
      name: nginx
    - git_url: https://git.openstack.org/openstack/fuel-ccp-openstack-base
      name: openstack-base
    - git_url: https://git.openstack.org/openstack/fuel-ccp-rabbitmq
      name: rabbitmq
    - git_url: https://git.openstack.org/openstack/fuel-ccp-ceph
      name: ceph
    - git_url: https://git.openstack.org/openstack/fuel-ccp-ironic
      name: ironic
    - git_url: https://git.openstack.org/openstack/fuel-ccp-rally
      name: rally

configs:
    private_interface: ens3
    public_interface: ens4
    neutron:
      physnets:
        - name: "physnet1"
          bridge_name: "br-ex"
          interface: "ens4"
          flat: true
          vlan_range: "1001:1030"
          dpdk: false
    etcd:
      tls:
        enabled: false
    rally:
      tempest:
        openstack_release: ${VERSION}
nodes:
  node[1-3]:
    roles:
      - controller-net-bridge
  node1:
    roles:
      - db
      - messaging
      - openvswitch
      - controller-net-host
  node[2-3]:
    roles:
      - db
      - messaging
      - openvswitch
      - compute
sources:
  openstack/cinder:
    git_url: https://git.openstack.org/openstack/cinder.git
    git_ref: ${BRANCH}
  openstack/ironic:
    git_url: https://git.openstack.org/openstack/ironic.git
    git_ref: ${BRANCH}
  openstack/murano:
    git_url: https://git.openstack.org/openstack/murano.git
    git_ref: ${BRANCH}
  openstack/murano-dashboard:
    git_url: https://git.openstack.org/openstack/murano-dashboard.git
    git_ref: ${BRANCH}
  openstack/sahara:
    git_url: https://git.openstack.org/openstack/sahara.git
    git_ref: ${BRANCH}
  openstack/sahara-dashboard:
    git_url: https://git.openstack.org/openstack/sahara-dashboard.git
    git_ref: ${BRANCH}
  openstack/keystone:
    git_url: https://git.openstack.org/openstack/keystone.git
    git_ref: ${BRANCH}
  openstack/horizon:
    git_url: https://git.openstack.org/openstack/horizon.git
    git_ref: ${BRANCH}
  openstack/nova:
    git_url: https://git.openstack.org/openstack/nova.git
    git_ref: ${BRANCH}
  openstack/neutron:
    git_url: https://git.openstack.org/openstack/neutron.git
    git_ref: ${BRANCH}
  openstack/heat:
    git_url: https://git.openstack.org/openstack/heat.git
    git_ref: ${BRANCH}
  openstack/glance:
    git_url: https://git.openstack.org/openstack/glance.git
    git_ref: ${BRANCH}
  openstack/requirements:
    git_url: https://git.openstack.org/openstack/requirements.git
    git_ref: ${BRANCH}
services:
  database:
    service_def: galera
  rpc:
    service_def: rabbitmq
  notifications:
    service_def: rabbitmq
roles:
  db:
    - database
  messaging:
    - rpc
    - notifications
  controller-net-host:
    - neutron-dhcp-agent
    - neutron-l3-agent
    - neutron-metadata-agent
  controller-net-bridge:
    - etcd
    - glance-api
    - glance-registry
    - heat-api-cfn
    - heat-api
    - heat-engine
    - horizon
    - keystone
    - memcached
    - neutron-server
    - nova-api
    - nova-conductor
    - nova-consoleauth
    - nova-novncproxy
    - nova-scheduler
  compute:
    - nova-compute
    - nova-libvirt
  openvswitch:
    - neutron-openvswitch-agent
    - openvswitch-db
    - openvswitch-vswitchd

EOF
}

ccp_wait_for_deployment_to_finish () {
    cnt=0
    until [[ `${SSH_COMMAND} ccp status -s -f value -c status` == "ok" ]]; do
        echo "Waiting for OpenStack deployment to finish..."
        sleep 5
        cnt=$((cnt + 1))
        if [ ${cnt} -eq $1 ]; then
            echo "Max time exceeded"
            ${SSH_COMMAND} ccp status
            ${SSH_COMMAND} fuel-ccp/tools/diagnostic-snapshot.sh -n ccp -c ccp.yml
            return 1
        fi
    done
    echo "...................................."
    echo "Jobs and pods in namespace: ccp"
    ${SSH_COMMAND} kubectl --namespace ccp get jobs
    ${SSH_COMMAND} kubectl --namespace ccp get pods
    echo "openrc file: openrc-ccp"
    ${SSH_COMMAND} cat openrc-ccp
    echo "...................................."
}

function ccp_install {
    ${SSH_COMMAND} "sudo -H pip install -r fuel-ccp/requirements.txt"
    ${SSH_COMMAND} "sudo -H pip install fuel-ccp/"
}


function deploy_ccp {
    pwd
    ${SSH_COMMAND} "ccp -vvv --debug --config-file ~/ccp.yml build -c etcd memcached rabbitmq galera percona rabbitmq"
    ${SSH_COMMAND} "ccp -vvv --debug --config-file ~/ccp.yml deploy -c etcd memcached database rpc notifications"
    ccp_wait_for_deployment_to_finish 70
    if [ $? -ne 0 ]; then
        return 1
    fi
    ${SSH_COMMAND} "ccp -vvv --debug --config-file ~/ccp.yml build"
    ${SSH_COMMAND} "ccp -vvv --debug --config-file ~/ccp.yml deploy"
    ccp_wait_for_deployment_to_finish 200
    if [ $? -ne 0 ]; then
        return 1
    fi
}

prepare_k8s_env


# Get IP address of first node in the cluster:
ADMIN_IP=$(ENV_NAME=${FUEL_DEVOPS_ENV_NAME} python fuel-ccp-installer/utils/jenkins/env.py get_slaves_ips | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
SSH_COMMAND="sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@${ADMIN_IP}"
SCP_COMMAND="sshpass -p vagrant scp -o StrictHostKeyChecking=no"

# remove old key:
ssh-keygen -R "${ADMIN_IP}"

# Let's wait 5 sec to all vms up
sleep 5

# Store info about Jenkins job on VM:
echo "${BUILD_TAG}" | ${SSH_COMMAND} "tee -a JENKINS_INFO.TXT"

fix_restored_env
copy_code_to_vm



# set version of openstack
if [ "${VERSION}" == "master" ];then
    export IMAGES_TAG="latest"
    export BRANCH="master"
elif [ "${VERSION}" == "ocata" ];then
    export IMAGES_TAG="ocata"
    export BRANCH="stable/ocata"
elif [ "${VERSION}" == "newton" ]; then
    export IMAGES_TAG="newton"
    export BRANCH="stable/newton"
else
    export IMAGES_TAG="mitaka"
    export BRANCH="stable/mitaka"
fi

prepare_ccp_config

ccp_install

if [ ${COMPONENT} == "smoke" ]; then
    sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@"${ADMIN_IP}" "echo ${SHARE_IP} share01-scc.ng.mirantis.net |sudo tee -a /etc/hosts"
    ssh -i ~/.ssh/jenkins_storage share@share01-scc.ng.mirantis.net rm /srv/static/share/tests/tests/result-${VERSION}.xml
    ${SCP_COMMAND} ccp.yml vagrant@"${ADMIN_IP}":~/
    ${SSH_COMMAND} "ccp -vvv --debug --config-file ~/ccp.yml fetch"
    ${SCP_COMMAND} -r ~/skel/* vagrant@"${ADMIN_IP}":/tmp/ccp-repos/rally/service/files
    set +e
    # Run CCP deployment and OpenStack tests:
    deploy_ccp
    DEPLOY_STATUS=$?
    #set tag dependent from test result
    if [[ "${DEPLOY_STATUS}" != 0 ]]; then
        echo "Deployment failed! Check diagnostic snapshot."
        ${SCP_COMMAND} vagrant@"${ADMIN_IP}":~/tmp/ccp-diag/*.tar.gz .
        scp -i ~/.ssh/jenkins_storage *.tar.gz share@share01-scc.ng.mirantis.net:/srv/static/share/tests/diagnostic/
        exit 1
    fi

    sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@"${ADMIN_IP}" "echo ${DOCKER_REGISTRY_IP} ${DOCKER_REGISTRY_HOST} |sudo tee -a /etc/hosts"
    TEMPEST_NAME=`sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@"${ADMIN_IP}" "ccp -vvv --debug --config-file ~/ccp.yml action run tempest -f value -c name"`

    stop = 0
    until [ ${stop} -eq 1 ]; do
        test_status=`${SSH_COMMAND} ccp -vvv --debug action status ${TEMPEST_NAME} -f value -c status`
        if [ "${test_status}" == "fail" ]; then
            stop=1
            DOCKER_TAG="${IMAGES_TAG}-unstable"
        elif [ "${test_status}" == "ok" ]; then
            stop=1
            DOCKER_TAG="${IMAGES_TAG}"
        else
            sleep 60
        fi
    done


    ${SSH_COMMAND} kubectl -n ccp logs ${TEMPEST_NAME} | grep -A 9 Totals
    ${SSH_COMMAND} kubectl -n ccp logs ${TEMPEST_NAME} -p | grep -A 9 Totals
    wget http://share01-scc.ng.mirantis.net/tests/tests/result-${VERSION}.xml
    set -e

    IMG=`sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@${ADMIN_IP} docker images --format "{{.Repository}}" | awk -F'/' -v search=/${IMAGES_NAMESPACE}/ '$0 ~ search {print $3}'`

    # we need docker config file to authentication in remote repository
    sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@"${ADMIN_IP}" mkdir -p /home/vagrant/.docker/
    sshpass -p vagrant scp -o StrictHostKeyChecking=no /home/jenkins/.docker/config.json vagrant@"${ADMIN_IP}":~/.docker/

    for f in ${IMG}; do
        sshpass  -p vagrant ssh -o StrictHostKeyChecking=no vagrant@"${ADMIN_IP}" \
        "docker tag ${REGISTRY_IP}:${REGISTRY_PORT}/${IMAGES_NAMESPACE}/$f:latest ${DOCKER_REGISTRY}/${REGISTRY_NAMESPACE}/${f}:${DOCKER_TAG} && docker push ${DOCKER_REGISTRY}/${REGISTRY_NAMESPACE}/${f}:${DOCKER_TAG}"
        if [ "${IMAGES_TAG}" == "ocata" ]; then
            sshpass  -p vagrant ssh -o StrictHostKeyChecking=no vagrant@"${ADMIN_IP}" \
            "docker tag ${REGISTRY_IP}:${REGISTRY_PORT}/${IMAGES_NAMESPACE}/${f}:latest ${DOCKER_REGISTRY}/${REGISTRY_NAMESPACE}/${f}:latest \
            && docker push ${DOCKER_REGISTRY}/${REGISTRY_NAMESPACE}/${f}:latest"
        fi
    done
else
    set +e
     # Run CCP deployment and OpenStack tests:
    deploy_ccp
    DEPLOY_STATUS=$?
    echo "Deploy status: ${DEPLOY_STATUS}"
    set -e
fi

# Revert to fresh to decrease image size
dos.py revert "${FUEL_DEVOPS_ENV_NAME}" "${FUEL_DEVOPS_SNAPSHOT_NAME}"

# Clean-up (snapshot should remain for next jobs):
dos.py destroy "${FUEL_DEVOPS_ENV_NAME}"
