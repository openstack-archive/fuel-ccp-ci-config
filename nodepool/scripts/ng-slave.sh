#!/bin/bash -ex

# Fix problem with hostname
sudo hostname $HOSTNAME
if [ -n "$HOSTNAME" ] && ! grep -q $HOSTNAME /etc/hosts ; then
    echo "127.0.1.1 $HOSTNAME" | sudo tee -a /etc/hosts
fi

sudo adduser --disabled-password --gecos "jenkins user" --home /home/jenkins jenkins
sudo mkdir /home/jenkins/.ssh

# ssh keys for jenkins user
cat << 'EOF' | sudo tee -a /home/jenkins/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKUgMk+HhqWFV3CwFdqsttUAqen+q5ahjb2DcFWcd8VaXK2dGHVugIa1bcHqWXYCXcqDDNWsB35XBJ7eEz26Hz5y40LKPu5wsTiWJpBAXuBWjxenz+9TK9Q3vZp6IqkiOx+3MJzXBw0iY6qn4lLfpfPjHqDDMQsFmrBidDxSh8lcQFQZlm+XPaclOPMzFNJ5CgL12/UMQAj4g/FiA/7Xx5qjRQuwNdixrHSa9P9jAFCGEHnOJfNFCL5FGq4Nyy9WUXrRJtjh2n0tUh0r83m8CL+8WXaTEhjqNSXwcbJzrO+LVtRmpQOYJohvzCDuiB9djbhj3WlHuEJqLt4uq6SZ/p nodepool
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCubqxYGmnTxVqrFGGU43EGt/a3HhL5eLDGUFsSkVdkRVt/zWo1T6vyLqoh3SnUPDC02DrSm+yrzO5ispVMPfwfLQXVVXijcIM025suGzdUFIN2RQQHMTJrx+yPo8F+iwIfsm0YflDlBGHfUWqRL9l7Mz6nTFyL8WVdPPwsobDeuBrDnZ5N5WuXbv0s9ooiSVuHGQFjNTLgskCLRaX/77ViHmH6d90JzufbTOJ8kO0BZTFps8R1jO27EuMySgR7sgWFHFKTL3XiPk8OHmVGyGSET4oM0rRwQHSTZul1blmFtFP0AnIEqhRlt9P6e9MqSryXzv15CBkQdZLHbdIpU+WV jenkins@nextgen-jenkins02-scc.ng.mirantis.net
EOF

# ssh keys for root user TEMPORARY
sudo mkdir /root/.ssh || true
cat << 'EOF' | sudo tee -a /root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKUgMk+HhqWFV3CwFdqsttUAqen+q5ahjb2DcFWcd8VaXK2dGHVugIa1bcHqWXYCXcqDDNWsB35XBJ7eEz26Hz5y40LKPu5wsTiWJpBAXuBWjxenz+9TK9Q3vZp6IqkiOx+3MJzXBw0iY6qn4lLfpfPjHqDDMQsFmrBidDxSh8lcQFQZlm+XPaclOPMzFNJ5CgL12/UMQAj4g/FiA/7Xx5qjRQuwNdixrHSa9P9jAFCGEHnOJfNFCL5FGq4Nyy9WUXrRJtjh2n0tUh0r83m8CL+8WXaTEhjqNSXwcbJzrO+LVtRmpQOYJohvzCDuiB9djbhj3WlHuEJqLt4uq6SZ/p nodepool
EOF

sudo chown jenkins:jenkins -R /home/jenkins/.ssh
sudo chmod 600 /home/jenkins/.ssh/authorized_keys

# update system and install git
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y git

# clone puppet repository
sudo git clone https://github.com/fuel-infra/puppet-manifests.git /etc/puppet

export DEBIAN_FRONTEND="noninteractive"
export PUPPET_ETC_DIR="/etc/puppet"
export HIERA_VAR_DIR="/var/lib/hiera"
sudo apt-get install -y puppet apt-transport-https

sudo mkdir -p ${HIERA_VAR_DIR}
sudo cp -ar ${PUPPET_ETC_DIR}/hiera/{distros,nodes,locations,roles} ${HIERA_VAR_DIR}/
sudo cp -ar ${PUPPET_ETC_DIR}/hiera/common-example.yaml ${HIERA_VAR_DIR}/common.yaml

# install java, required to connect from jenkins
sudo apt-get install -y openjdk-7-jre-headless

#puppet apply -vd  --detailed-exitcodes --color=false --modulepath=/etc/puppet/modules -e "class {'fuel_project::jenkins::slave': run_tests => true,}"

exit 0

