#!/bin/bash

set -ex

OUTPUT_PATH="${WORKSPACE}/bootstrap/output-qemu"

curl -o "${ARCHIVE}" "${URL}"
unzip -o "${ARCHIVE}" -d ./bootstrap
rm "${ARCHIVE}"

cd ./bootstrap

rm -rf "${OUTPUT_PATH}"
headless=true ./packer build --only qemu -color=false solar-master.json

cp -f "${OUTPUT_PATH}/${IMAGE_NAME}" "${IMAGE_DST_DIR}"
