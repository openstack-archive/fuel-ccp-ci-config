#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

export HOME=${WORKSPACE}
export GOPATH=${HOME}/_gopath

# Update path to use scripts from repository and localy installed etcd
export PATH=${GOPATH}/bin:${HOME}/third_party/etcd:$PATH

# install etcd
# it will be downloaded and unpacked in third_party/etcd directory
./hack/install-etcd.sh

# install junit report library
go get -u github.com/jstemmer/go-junit-report

# Enable the Go race detector.
export KUBE_RACE=-race
# Produce a JUnit-style XML test report for Jenkins.
#export KUBE_JUNIT_REPORT_DIR=${WORKSPACE}/_artifacts
# Save the verbose stdout as well.
export KUBE_KEEP_VERBOSE_TEST_OUTPUT=y

"${TEST_SCRIPT}"
