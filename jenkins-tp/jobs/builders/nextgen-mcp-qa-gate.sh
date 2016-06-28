#!/bin/bash -xe

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

function check_venv_exists() {
  VIRTUAL_ENV=mcp-qa-venv

  if [ -f ${VIRTUAL_ENV}/bin/activate ]; then
    source ${VIRTUAL_ENV}/bin/activate
    echo "Python virtual env exist"
  else
    rm -rf ${VIRTUAL_ENV}
    virtualenv  --no-site-packages ${VIRTUAL_ENV}
    source ${VIRTUAL_ENV}/bin/activate
  fi
}

check_venv_exists

pip install -r mcp_tests/requirements.txt

py.test -k mysql_is_running

deactivate