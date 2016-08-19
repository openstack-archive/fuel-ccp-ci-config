#!/bin/bash

set -ex

mkdir -p /home/jenkins/workspace/cloud-images/

echo "** Updating Ubuntu image"
rsync -v -r -e 'ssh -o StrictHostKeyChecking=no' $STORAGE_USER@$STORAGE_HOST:. /home/jenkins/workspace/cloud-images/
