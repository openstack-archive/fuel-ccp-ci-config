#!/bin/bash

cd containers/$ZUUL_PROJECT

CHANGED=`git diff --name-only origin/master HEAD`

echo "$CHANGED" | grep heka
if [ $? -eq 0 ]; then
	COMP_LIST="$COMP_LIST heka"
fi

echo "$CHANGED" | grep elasticsearch
if [ $? -eq 0 ]; then
	COMP_LIST="$COMP_LIST elasticsearch"
fi

echo "$CHANGED" | grep influxdb
if [ $? -eq 0 ]; then
	COMP_LIST="$COMP_LIST influxdb"
fi

echo "$CHANGED" | grep kibana
if [ $? -eq 0 ]; then
	COMP_LIST="$COMP_LIST kibana"
fi

echo "$CHANGED" | grep grafana
if [ $? -eq 0 ]; then
	COMP_LIST="$COMP_LIST grafana"
fi

if [ -z $COMP_LIST ]; then
	COMP_LIST="heka elasticsearch influxdb kibana grafana"
fi

cd $WORKSPACE

virtualenv stacklightenv
source stacklightenv/bin/activate
pip install fuel-ccp/
mcp-microservices --images-maintainer mirantis@mirantis.com \
    --images-namespace stacklightbuild --images-tag latest \
    --repositories-names fuel-ccp-debian-base,fuel-ccp-openstack-base,fuel-ccp-stacklight \
    --builder-no-cache \
    --repositories-path containers/openstack \
    build -c $COMP_LIST
deactivate

