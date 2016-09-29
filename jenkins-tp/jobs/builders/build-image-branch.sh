#!/bin/bash -xe

JOB_NAME={name}
OS_VER={GIT_BRANCH}

virtualenv ${JOB_NAME}env
source ${JOB_NAME}env/bin/activate
pip install --upgrade pip
pip install fuel-ccp/
if [ ${OS_VER} == "master" ] || [ ${OS_VER} == "all" ]; then
    GIT_BRANCH=master
else
    GIT_BRANCH=stable/newton
fi
cat > ccp-test.yaml << EOF
debug: True
builder:
  no_cache: True
images:
  namespace: {name}build
  tag: latest
  maintainer: mirantis@mirantis.com
repositories:
  path: containers/openstack
  skip_empty: True
  names: [{repos}]
sources:
  openstack/keystone:
    git_url: https://github.com/openstack/keystone.git
    git_ref: ${GIT_BRANCH}
  openstack/horizon:
    git_url: https://github.com/openstack/horizon.git
    git_ref: ${GIT_BRANCH}
  openstack/nova:
    git_url: https://github.com/openstack/nova.git
    git_ref: ${GIT_BRANCH}
  openstack/neutron:
    git_url: https://github.com/openstack/neutron.git
    git_ref: ${GIT_BRANCH}
  openstack/heat:
    git_url: https://github.com/openstack/heat.git
    git_ref: ${GIT_BRANCH}
  openstack/keystone:
    git_url: https://github.com/openstack/keystone.git
    git_ref: ${GIT_BRANCH}
  openstack/glance:
    git_url: https://github.com/openstack/glance.git
    git_ref: ${GIT_BRANCH}
  openstack/horizon:
    git_url: https://github.com/openstack/horizon.git
    git_ref: ${GIT_BRANCH}
EOF

cat ccp-test.yaml
ccp --config-file ccp-test.yaml build

deactivate

