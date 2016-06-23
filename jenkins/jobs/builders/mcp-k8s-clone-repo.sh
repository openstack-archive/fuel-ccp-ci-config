#!/bin/bash

set -ex

# clone repo from local copy
git clone file:///home/jenkins/kubernetes .

# Set correct remote
git remote set-url origin ssh://nextgen-ci@review.fuel-infra.org:29418/kubernetes/kubernetes

if ! git remote update; then
    echo "The remote update failed, so garbage collecting before trying again."
    git gc
    git remote update
fi

git reset --hard
if ! git clean -x -f -d -q ; then
    sleep 1
    git clean -x -f -d -q
fi

if echo "${ZUUL_REF}" | grep -q ^refs/tags/; then
    git fetch --tags "${ZUUL_URL}/${ZUUL_PROJECT}"
    git checkout "${ZUUL_REF}"
    git reset --hard ${ZUUL_REF}
elif [ -z "${ZUUL_NEWREV}" ]; then
    git fetch "${ZUUL_URL}/${ZUUL_PROJECT}" "${ZUUL_REF}"
    git checkout FETCH_HEAD
    git reset --hard FETCH_HEAD
else
    git checkout "${ZUUL_NEWREV}"
    git reset --hard "${ZUUL_NEWREV}"
fi

if ! git clean -x -f -d -q ; then
    sleep 1
    git clean -x -f -d -q
fi
