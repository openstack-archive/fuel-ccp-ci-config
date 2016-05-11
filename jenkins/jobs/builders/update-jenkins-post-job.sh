#!/bin/bash -xe


echo "This is job for update jenkins jobs after merge"

git clone ssh://nextgen-ci@review.fuel-infra.org:29418/$ZUUL_PROJECT .

cat > jenkins_jobs.ini << EOF
[jenkins]
user=${JJB_USER}
password=${JJB_PASS}
url=https://jenkins.ng.mirantis.net/
query_plugins_info=False
[job_builder]
ignore_cache=True
recursive=True
EOF

jenkins-jobs --conf jenkins_jobs.ini update jenkins/jobs
