#!/bin/bash -xe

rand=zuulenv-`echo $RANDOM`

virtualenv $rand
source $rand/bin/activate
pip install zuul

CLONEMAP=`mktemp`

cat > $CLONEMAP << EOF
          clonemap:
            - name: $ZUUL_PROJECT
              dest: $ZUUL_PROJECT
EOF
zuul-cloner -m $CLONEMAP --cache-dir /opt/git \
      ssh://nextgen-ci@review.fuel-infra.org:29418 $ZUUL_PROJECT


deactivate
