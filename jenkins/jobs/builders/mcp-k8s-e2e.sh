#!/bin/bash

set -ex

export HOME=${WORKSPACE}
export GOPATH=${HOME}/_gopath
export PATH=${GOPATH}/bin:${PATH}
export ARTIFACTS=${WORKSPACE}/_artifacts

export KUBERNETES_PROVIDER=libvirt-coreos

mkdir -p "${ARTIFACTS}"

#enable ksm
echo 1|sudo tee /sys/kernel/mm/ksm/run

#get coreos image
ln /home/jenkins/coreos_production_qemu_image.img.bz2 cluster/libvirt-coreos/coreos_production_qemu_image.img.bz2

#generate temporary key for k8s cluster
mkdir .ssh
ssh-keygen -N "" -f ${HOME}/.ssh/id_rsa

make release-skip-tests

./cluster/kube-up.sh

go run hack/e2e.go -v -test --test_args="--host=https://192.168.10.1:6443 --report-dir=${ARTIFACTS} --ginkgo.focus=\[Conformance\]"
