#!/bin/bash -xe

virtualenv mariadbenv

source mariadbenv/bin/activate

cd microservices

pip install .

cd ..

mcp-microservices --images-base-distro debian --images-base-tag 8.4 \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace mariadbbuild --images-tag latest \
    --repositories-path containers/nextgen --auth-gerrit-username nextgen-ci \
    build

ts=`date +%s`

docker run -d --name mariadb-${ts} -it -e DB_ROOT_PASSWORD="password" \
           mariadbbuild/mariadb:latest

sleep 20

docker exec mariadb-${ts} mysql -u root -ppassword -e "show databases"

docker stop mariadb-${ts}
docker rm mariadb-${ts}

deactivate

