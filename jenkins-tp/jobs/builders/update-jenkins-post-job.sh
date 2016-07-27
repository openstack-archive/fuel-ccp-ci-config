#!/bin/bash -xe


echo "This is job for update jenkins jobs after merge"

git clone https://git.openstack.org/$ZUUL_PROJECT .

tox -e fuel-ccp-ci

source ".tox/fuel-ccp-ci/bin/activate"

JENKINS-TP_IP=172.18.229.11

cat > jenkins_jobs.ini << EOF
[jenkins]
user=${JJB_USER}
password=${JJB_PASS}
url=https://${JENKINS-TP_IP}/
query_plugins_info=False
[job_builder]
ignore_cache=True
recursive=True
EOF

jenkins-jobs --flush-cache --conf jenkins_jobs.ini update \
	                           --delete-old jenkins-tp/jobs

deactivate
