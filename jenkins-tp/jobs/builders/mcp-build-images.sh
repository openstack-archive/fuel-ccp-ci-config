#!/bin/bash -ex

ls -al

virtualenv mcp
source mcp/bin/activate
pip install .

ccp \
--images-maintainer mos-microservices@mirantis.com \
--builder-no-cache \
--builder-push \
--auth-registry \
--builder-registry registry.mcp.fuel-infra.org \
--auth-registry-username $REG_USER \
--auth-registry-password $REG_PASS \
--images-namespace mcp \
--images-tag latest \
--repositories-path microservices-repos \
build

deactivate
