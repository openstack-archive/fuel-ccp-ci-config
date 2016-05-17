#!/bin/bash -ex

ls -al

virtualenv mcp
source mcp/bin/activate
pip install .

mcp-microservices --images-base_distro debian --images-base_tag 8.4 \
--images-maintainer mirantis@mirantis.com --images-namespace mcp \
--images-tag latest --repositories-path mirantis/mcp \
--auth-gerrit-username nextgen-ci \
build

deactivate
