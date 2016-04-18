#!/bin/bash -x
# Quick & dirty cleanup script for AIO kolla/kolla-mesos environemnt.
# To be used if redepolyment fails on the same machine.
# Please use with care!
#
# (c) mzawadzki@mirantis.com

echo "Stopping and removing mesos docker containers..."
docker stop mesos_slave chronos marathon mesos_master zookeeper mesos-dns
docker rm mesos_slave chronos marathon mesos_master zookeeper mesos-dns

sleep 5

echo "Stopping and removing all kolla docker containers..."
docker ps -a | grep kolla | awk '{system("docker stop -t 0 "$1)}'
docker ps -a | grep kolla | awk '{system("docker rm -f "$1)}'

echo "Removing kolla docker volumes..."
docker volume ls | grep -e mariadb_kolla -e zookeeper_data \
-e kolla_logs_kolla -e neutron_metadata_socket \
| awk '{system("docker volume rm "$2)}'

#echo "Removing files in /tmp"
#rm -rf /tmp/.ansible*
#rm -rf /tmp/kolla*
#rm -rf /tmp/mesos
