#!/bin/bash -xe

rand=zuulenv-`echo $RANDOM`

virtualenv $rand
source $rand/bin/activate
pip install zuul

CLONEMAP=`mktemp`

cat > $CLONEMAP << EOF
          clonemap:
            - name: $ZUUL_PROJECT
              dest: .
EOF
zuul-cloner -m $CLONEMAP --cache-dir /opt/git \
      ssh://nextgen-ci@review.fuel-infra.org $ZUUL_PROJECT


deactivate
