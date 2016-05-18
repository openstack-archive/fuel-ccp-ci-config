#!/bin/bash -xe

virtualenv mariadbenv

source mariadbenv/bin/activate

cd microservices

pip install .

cd ..

mcp-microservices --images-base_distro debian --images-base_tag 8.4 \
    --images-maintainer mirantis@mirantis.com \
    --images-namespace mariadbbuild --images-tag latest \
    --repositories-path containers --auth-gerrit-username nextgen-ci \
    build

ts=`date +%s`

docker run -d --name mariadb-${ts} -it -e DB_ROOT_PASSWORD="password" \
           registry01-bud.ng.mirantis.net/test/mariadb:latest

sleep 20

docker exec -it mariadb-${ts} mysql -u root -ppassword -e "show databases"

docker stop mariadb-${ts}
docker rm mariadb-${ts}

deactivate

docker rmi $(docker images | awk '/mariadbbuild/ {print $3}')

