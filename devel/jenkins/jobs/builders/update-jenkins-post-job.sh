#!/bin/bash -xe


echo "This is job for update jenkins jobs after merge"

git clone ssh://nextgen-ci01-dev@review.fuel-infra.org:29418/$ZUUL_PROJECT .

tox -e nextgen-ci

source ".tox/nextgen-ci/bin/activate"

cat > jenkins_jobs.ini << EOF
[jenkins]
user=${JJB_USER}
password=${JJB_PASS}
url=https://ci01-dev.ng.mirantis.net/
query_plugins_info=False
[job_builder]
ignore_cache=True
recursive=True
EOF

jenkins-jobs --flush-cache --conf jenkins_jobs.ini update --delete-old jenkins/jobs
