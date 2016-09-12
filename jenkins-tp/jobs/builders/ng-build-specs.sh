#!/bin/bash

set -ex

echo "** Building docs from rst files:"
tox -e docs
ls -al doc/build/html/

echo "** Uploading HTML docs to the server:"
rsync -v -r --delete -e ssh doc/build/html docs-publisher@docs.ng.mirantis.net:~/
