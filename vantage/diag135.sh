#!/bin/bash
set +e
D=/root/ul
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
echo "### ENV $(date -u +%FT%TZ)"
ls -la "$D"/ 2>/dev/null | head -20
ls -la "$D/wildrig-multi" /opt/t19/wildrig-multi* 2>/dev/null
file "$D/wildrig-multi" 2>/dev/null; md5sum "$D/wildrig-multi" 2>/dev/null
echo "### PLH-SCRIPTS"
ls -la /opt/plh/ 2>/dev/null
echo "--- run_gpu.sh"; cat /opt/plh/run_gpu.sh 2>/dev/null | head -60
echo "--- keepalive.sh (now)"; cat /opt/plh/keepalive.sh 2>/dev/null | head -20
echo "### UNITS-STATE"
for i in 0 1 7; do echo "plh-card@$i: enabled=$(systemctl is-enabled plh-card@$i 2>&1) active=$(systemctl is-active plh-card@$i 2>&1)"; done
systemctl is-active ul-pearl-keep; systemctl is-enabled ul-pearl-keep 2>&1
echo "### JOURNAL"
journalctl -u plh-card@0 -n 20 --no-pager 2>/dev/null
journalctl -u ul-pearl-keep -n 20 --no-pager 2>/dev/null
echo "### FOREGROUND-TEST"
timeout 20 "$D/wildrig-multi" --algo pearlhash --url pool.pearlhash.xyz:9000 --user "$WALLET" --worker ul-t2-123-184-7-135-g0 --pass x --protocol stratum --opencl-devices 0 --gpu-intensity 1 --api-port 1960 2>&1 | tail -25
echo "rc=$?"
echo "### DMESG"
dmesg 2>/dev/null | tail -20
echo "### PS"
ps -eo pid,args | grep -E 'wildrig|krig|plh' | grep -v grep
echo "### NVIDIA"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>&1
echo "### DONE-DIAG"
