#!/bin/bash -ex

rep=`ssh -o StrictHostKeyChecking=no -p 29418 mirantis-fuel-ccp-ci@review.openstack.org gerrit ls-projects | grep "fuel-ccp-"| tr '\n' ' '`

tee -a clonemap.yaml << EOF
clonemap:
    - name: openstack/fuel-ccp
      dest: fuel-ccp
EOF

for f in ${rep}; do
tee -a clonemap.yaml << EOF
    - name: ${f}
      dest: containers/${f/fuel-ccp-/}
EOF
done

source /home/jenkins/venv-zuul/bin/activate
zuul-cloner -m clonemap.yaml ssh://mirantis-fuel-ccp-ci@review.openstack.org:29418 openstack/fuel-ccp ${rep}
deactivate
