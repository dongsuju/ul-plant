#!/bin/bash
set +e
echo "###P25START $(date -u)"
pgrep -fa '/root/q/' | head -5
ls -l /root/q/
echo "=== P24-LOG-HEAD ==="; head -c 2500 /root/q/p24.log 2>&1
echo; echo "=== P24-LOG-TAIL ==="; tail -c 7000 /root/q/p24.log 2>&1
echo "=== PROXYNET ==="; cat /.onething/instance/configmap/proxyNetConfig.json 2>&1 | head -30
echo "###P25END $(date -u)"
