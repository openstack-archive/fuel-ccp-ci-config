#!/bin/bash -ex

# Deploys CCP and runs simple, built-in OpenStack tests.
# Kubernetes cluster is expected to be pre-deployed and snapshoted - if not
# this script will ensure this.
# The script expects fuel-ccp cloned into fuel-ccp/ and fuel-ccp-installer
# cloned into fuel-ccp-installer/ directory (e.g. by Jenkins SCM plugin).


# CONFIGURATION:
######################################################
: ${FUEL_DEVOPS_ENV_NAME:="fuel-ccp-debug-${VERSION}-deployment"}
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

sed -i 's/127.0.0.1:31500/'${REGISTRY_IP}':'${REGISTRY_PORT}'/g' fuel-ccp/tools/ccp-multi-deploy/config/ccp-configs-common.yaml
cat >> fuel-ccp/tools/ccp-multi-deploy/config/ccp-configs-common.yaml << EOF
images:
  tag: "${BUILD_ID}"
EOF

${SCP_COMMAND} -r fuel-ccp/ vagrant@"${ADMIN_IP}":~/


# Run CCP deployment and OpenStack tests:
${SSH_COMMAND} "pushd fuel-ccp && APT_CACHE_SERVER=http://${APT_CACHE_SERVER_IP}:${APT_CACHE_SERVER_PORT} tox -e multi-deploy -- --openstack-version ${VERSION} --number-of-envs 1 -d"

docker exec "${REGISTRY_HASH}" sudo chgrp -R "${JENKINS_GID}" /var/lib/registry
docker exec "${REGISTRY_HASH}" sudo chmod -R  g+w /var/lib/registry

for i in `curl http://${REGISTRY_IP}:${REGISTRY_PORT}/v2/_catalog | jq -r '.repositories[]'`; do
        REGISTRY_DATA_DIR=/home/jenkins/registry/data/docker/registry/v2/ /home/jenkins/registry/delete_docker_registry_image.py --image "${i}":"${BUILD_ID}"
done


# Revert to fresh to decrease image size
dos.py revert "${FUEL_DEVOPS_ENV_NAME}" "${FUEL_DEVOPS_SNAPSHOT_NAME}"

# Clean-up (snapshot should remain for next jobs):
dos.py destroy "${FUEL_DEVOPS_ENV_NAME}"
