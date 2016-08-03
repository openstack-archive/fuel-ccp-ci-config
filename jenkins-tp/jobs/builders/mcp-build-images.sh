#!/bin/bash -ex

ls -al

virtualenv mcp
source mcp/bin/activate
pip install .

ccp \
--images-maintainer mos-microservices@mirantis.com \
--builder-no-cache \
--builder-push \
--registry-address registry.mcp.fuel-infra.org \
--registry-username $REG_USER \
--registry-password $REG_PASS \
--images-namespace mcp \
--images-tag latest \
--repositories-path microservices-repos \
build

deactivate
