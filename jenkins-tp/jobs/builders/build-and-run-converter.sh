#!/bin/bash

cat > Dockerfile << EOF
FROM debian:latest

RUN apt-get update \
        && apt-get -y install --no-install-recommends \
           qemu \
           libvirt-bin
EOF

docker build -t converter .
if `docker ps | grep converter`; then
    docker stop converter && docker rm converter
fi
docker run -d --restart=always --name converter -v /var/lib/libvirt/images/:/images converter:latest /bin/bash -c "while true; do ls -lash /images; sleep 10;done"
