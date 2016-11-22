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
export DOCKER_REGISTRY="registry.mcp.fuel-infra.org"
export IMAGES_NAMESPACE="ccp"
export REGISTRY_NAMESPACE="mcp"


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
export WORKSPACE="/home/jenkins/workspace"
export FUEL_DEVOPS_INSTALLATION_DIR=${FUEL_DEVOPS_INSTALLATION_DIR}
export CUSTOM_YAML='hyperkube_image_repo: "${HYPERKUBE_REPO}"
hyperkube_image_tag: "${HYPERKUBE_TAG}"
kube_version: "${HYPERKUBE_VERSION}"
docker_options: "--insecure-registry=${REGISTRY_IP}:${REGISTRY_PORT}"'

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

# Change registry ip address to slave and set tag
sed -i 's/127.0.0.1:31500/'${REGISTRY_IP}':'${REGISTRY_PORT}'/g' fuel-ccp/tools/ccp-multi-deploy/config/ccp-configs-common.yaml
cat >> fuel-ccp/tools/ccp-multi-deploy/config/ccp-configs-common.yaml << EOF
images:
  tag: "${ZUUL_CHANGE}"
EOF

# set version of openstack
if [ "${VERSION}" == "master" ];then
    export IMAGES_TAG="ocata"
else
    export IMAGES_TAG="newton"
fi


# Prepare env on "admin" VM:
if [ ${COMPONENT} == "full" ];then
    ${SCP_COMMAND} -r fuel-ccp/ vagrant@"${ADMIN_IP}":~/
elif [ ${COMPONENT} == "smoke" ];then
    ${SCP_COMMAND} -r fuel-ccp/ vagrant@"${ADMIN_IP}":~/
else
    ${SCP_COMMAND} -r fuel-ccp/ vagrant@"${ADMIN_IP}":~/
    # set +x is just for security reasons to avoid publishing internal IP
    set +x
    getent hosts zuul.mcp.fuel-infra.org | ${SSH_COMMAND} "sudo tee -a /etc/hosts"
    set -x
    ${SCP_COMMAND} -r containers/openstack/ vagrant@"${ADMIN_IP}":/tmp/ccp-repos
fi

<<<<<<< HEAD

set +e
# download snapshot if exists
${SCP_COMMAND} vagrant@"${ADMIN_IP}":/tmp/ccp-diag/*.tar.gz .

# remove images from local registry
for i in `curl http://${REGISTRY_IP}:${REGISTRY_PORT}/v2/_catalog | jq -r '.repositories[]'`; do
        REGISTRY_DATA_DIR=/home/jenkins/registry/data/docker/registry/v2/ /home/jenkins/registry/delete_docker_registry_image.py --image "${i}":"${ZUUL_CHANGE}"
done
set -e
=======
if [ ${COMPONENT} == "smoke" ]; then
    set +e
    # Run CCP deployment and OpenStack tests:
    ${SSH_COMMAND} "pushd fuel-ccp && APT_CACHE_SERVER=http://${APT_CACHE_SERVER_IP}:${APT_CACHE_SERVER_PORT} tox -e multi-deploy -- --openstack-version ${VERSION} --number-of-envs 1 -d"
    SMOKE_STATUS=$?
    set -e

    docker exec "${REGISTRY_HASH}" chgrp -R "${JENKINS_GID}" /var/lib/registry
    docker exec "${REGISTRY_HASH}" chmod -R  g+w /var/lib/registry

    #set tag dependent from test result
    if [[ "${SMOKE_STATUS}" == 0 ]]; then
        DOCKER_TAG="${IMAGES_TAG}"
    else
        DOCKER_TAG="${IMAGES_TAG}-unstable"
    fi

    IMG=`sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@${ADMIN_IP} docker images --format "{{.Repository}}" | awk -F'/' -v search=/${IMAGES_NAMESPACE}/ '$0 ~ search {print $3}'`

    # we need docker config file to authentication in remote repository
    sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@"${ADMIN_IP}" mkdir -p /home/vagrant/.docker/
    sshpass -p vagrant scp -o StrictHostKeyChecking=no /home/jenkins/.docker/config.json vagrant@"${ADMIN_IP}":~/.docker/

    for f in ${IMG}; do
        sshpass  -p vagrant ssh -o StrictHostKeyChecking=no vagrant@"${ADMIN_IP}" \
        "docker tag 127.0.0.1:31500/${IMAGES_NAMESPACE}/$f:latest ${DOCKER_REGISTRY}/${REGISTRY_NAMESPACE}/${f}:${DOCKER_TAG} && docker push ${DOCKER_REGISTRY}/${REGISTRY_NAMESPACE}/${f}:${DOCKER_TAG}"
        if [ "${IMAGES_TAG}" == "ocata" ]; then
            sshpass  -p vagrant ssh -o StrictHostKeyChecking=no vagrant@"${ADMIN_IP}" \
            "docker tag 127.0.0.1:31500/${IMAGES_NAMESPACE}/${f}:latest ${DOCKER_REGISTRY}/${REGISTRY_NAMESPACE}/${f}:latest \
            && docker push ${DOCKER_REGISTRY}/${REGISTRY_NAMESPACE}/${f}:latest"
        fi
    done
else
     # Run CCP deployment and OpenStack tests:
    ${SSH_COMMAND} "pushd fuel-ccp && APT_CACHE_SERVER=http://${APT_CACHE_SERVER_IP}:${APT_CACHE_SERVER_PORT} tox -e multi-deploy -- --openstack-version ${VERSION} --number-of-envs 1 -d"
fi

set +e
# download snapshot if exists
${SCP_COMMAND} vagrant@"${ADMIN_IP}":/tmp/ccp-diag/*.tar.gz .

# remove images from local registry
for i in `curl http://${REGISTRY_IP}:${REGISTRY_PORT}/v2/_catalog | jq -r '.repositories[]'`; do
        REGISTRY_DATA_DIR=/home/jenkins/registry/data/docker/registry/v2/ /home/jenkins/registry/delete_docker_registry_image.py --image "${i}":"$    {ZUUL_CHANGE}"
done
set -e


# Revert to fresh to decrease image size
dos.py revert "${FUEL_DEVOPS_ENV_NAME}" "${FUEL_DEVOPS_SNAPSHOT_NAME}"

# Clean-up (snapshot should remain for next jobs):
dos.py destroy "${FUEL_DEVOPS_ENV_NAME}"
