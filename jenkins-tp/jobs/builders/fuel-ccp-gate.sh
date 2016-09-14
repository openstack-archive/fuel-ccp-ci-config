#!/bin/bash -xe

virtualenv microenv

source microenv/bin/activate

pip install --upgrade pip

pip install .

cat > ccp-test.yaml << EOF
debug: True
builder:
  no_cache: True
images:
  namespace: microbuild
  tag: latest
  maintainer: mirantis@mirantis.com
repositories:
  path: containers/openstack
  skip_empty: True
EOF

ccp --config-file ccp-test.yaml build

deactivate

