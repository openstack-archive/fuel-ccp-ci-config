#!/bin/bash

set -ex

mkdir -p $IMAGE_SLAVE_PATH

echo "** Updating Ubuntu image"
rsync --delete-before -v -r -e 'ssh -o StrictHostKeyChecking=no' $STORAGE_USER@$STORAGE_HOST:. $IMAGE_SLAVE_PATH

cd $IMAGE_SLAVE_PATH

if [ -L default-image.qcow2 ];then
  rm default-image.qcow2
fi

lastfile=`ls -t1 | head -n 1`
ln -s $lastfile default-image.qcow2
