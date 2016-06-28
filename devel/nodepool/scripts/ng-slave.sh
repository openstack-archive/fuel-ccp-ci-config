#!/bin/bash

set -x

source /etc/profile

# Fix problem with hostname
hostname $HOSTNAME
if [ -n "$HOSTNAME" ] && ! grep -q $HOSTNAME /etc/hosts ; then
    echo "127.0.1.1 $HOSTNAME" | tee -a /etc/hosts
fi

# ssh keys for root user TEMPORARY
mkdir /root/.ssh
cat > /root/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQClT2iRC2/NyKxK+ZVHDMkAynwYBVOVeqABA4MBNecIXmlYEKpxT0uqKIOEFpeBxiune1saOeWdlqSlLRcM1uuVVLNZYMMY1Ys1iI46l+WKRFwuCrJM6eXiWllDCrG2rOhTodFW3LMFPRKat3uRL2pgeELEs2rwz0Jtx5ujcZ1Q4CJ8baQUXy0dn0Tul+8z02DGPttEJulM1GDtsHu1kXgadNFFbLZaoPMUqgxEv8uWV/vMM6c1lmDmwzEk4NV9CXedwg6GVgR9JvZ4sSuzAFOn7yDFJ9i6G2aGKaI+T6zdQtNAc5Qj9lx7YxeCEIXkIYl/6+Z2GaFqiV0jWFYe1JLR nodepool
EOF
chmod 600 /root/.ssh/authorized_keys

apt-get update
apt-get dist-upgrade -y
apt-get install puppet puppet-common -y

exit 0

# puppet part!
echo "puppet part!"
LOG_FILE="/var/log/firstboot.log"
touch "${LOG_FILE}"
chown root:root "${LOG_FILE}"
chmod 400 "${LOG_FILE}"
# stoppping puppet agent if running
service puppet stop
if pgrep puppet; then
  pkill puppet
  sleep 5
  pkill -9 puppet
fi
puppet agent --enable
PUPPET_CMD="puppet agent \
        --debug \
        --verbose \
        --onetime \
        --no-daemonize \
        --show_diff"
PUPPET_MASTER="puppet.fuel-infra.org"
export FACTER_ROLE="nextgen_slave"
export FACTER_LOCATION="scc"
# if autosign is set it would apply manifests
timeout 30m $PUPPET_CMD --server "${PUPPET_MASTER}" 2>&1 | tee -a "${LOG_FILE}"
exit_code=$?
# Because we running with set -x we'll see this regex in $LOG_FILE
# so 'E[x]iting' with '[x]' is a hack to find this text from puppet
if grep 'E[x]iting; no certificate found and waitforcert is disabled' "${LOG_FILE}"; then
  timeout 30m $PUPPET_CMD --waitforcert 180 --server "${PUPPET_MASTER}" | tee -a "${LOG_FILE}"
  exit_code=$?
fi
rm -rf /var/lib/puppet/ssl/*
echo "Puppet exit code was: $exit_code"
if [[ ${exit_code} -eq 0 ]]; then
  reboot
fi

exit ${exit_code}
