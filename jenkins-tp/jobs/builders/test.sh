#!/bin/bash -e

echo "========= ID =========="
id

echo "========= ps =========="
ps axuf

echo "========= ls =========="
ls -la

echo "========= create log =========="
mkdir logs
echo "Test" >logs/test.log
