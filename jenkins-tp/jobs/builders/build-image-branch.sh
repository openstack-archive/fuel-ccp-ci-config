#!/bin/bash -xe

JOB_NAME={name}
OS_VER={GIT_BRANCH}
REPO_LIST={repos}

if [ $OS_VER == "master" ]; then
    GIT_BRANCH=master
else
    GIT_BRANCH=stable/newton
fi
tee > fuel-ccp/ccp-test.yaml << EOF
debug: True
builder:
  no_cache: True
images:
  namespace: $JOB_NAME-build
  tag: latest
  maintainer: mirantis@mirantis.com
repositories:
  path: $WORKSPACE/containers/openstack
  skip_empty: True
  names: [$REPO_LIST]
sources:
  openstack/cinder:
    git_url: https://github.com/openstack/cinder.git
    git_ref: $GIT_BRANCH
  openstack/ironic:
    git_url: https://github.com/openstack/ironic.git
    git_ref: $GIT_BRANCH
  openstack/murano:
    git_url: https://github.com/openstack/murano.git
    git_ref: $GIT_BRANCH
  openstack/murano-dashboard:
    git_url: https://github.com/openstack/murano-dashboard.git
    git_ref: $GIT_BRANCH
  openstack/sahara:
    git_url: https://github.com/openstack/sahara.git
    git_ref: $GIT_BRANCH
  openstack/sahara-dashboard:
    git_url: https://github.com/openstack/sahara-dashboard.git
    git_ref: $GIT_BRANCH
  openstack/keystone:
    git_url: https://github.com/openstack/keystone.git
    git_ref: $GIT_BRANCH
  openstack/horizon:
    git_url: https://github.com/openstack/horizon.git
    git_ref: $GIT_BRANCH
  openstack/nova:
    git_url: https://github.com/openstack/nova.git
    git_ref: $GIT_BRANCH
  openstack/neutron:
    git_url: https://github.com/openstack/neutron.git
    git_ref: $GIT_BRANCH
  openstack/heat:
    git_url: https://github.com/openstack/heat.git
    git_ref: $GIT_BRANCH
  openstack/glance:
    git_url: https://github.com/openstack/glance.git
    git_ref: $GIT_BRANCH
EOF

cd fuel-ccp
tox -e venv -- ccp --config-file ccp-test.yaml build

