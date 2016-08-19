#!/bin/bash

set -ex

mkdir -p $IMAGE_SLAVE_PATH

echo "** Updating Ubuntu image"
rsync -v -r -e 'ssh -o StrictHostKeyChecking=no' $STORAGE_USER@$STORAGE_HOST:. $IMAGE_SLAVE_PATH
