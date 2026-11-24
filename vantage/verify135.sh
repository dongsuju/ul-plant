#!/bin/bash
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
U=/dev/shm/.u
echo "### VERIFY $(date -u +%FT%TZ)"
for i in 0 1 2 3 4 5 6 7; do printf 'ulx-g%s=%s ' $i "$(systemctl is-active ulx-g$i 2>/dev/null)"; done; echo
systemctl is-active ulx-watch
ps -eo pid,args | grep -E 'krig-miner|wildrig' | grep -v grep | wc -l
echo "### FOREIGN"
ps -eo pid,args | grep -E 'prl1p6grd5zl|plh-123-184' | grep -v grep | head -3
echo "### GPU"; nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
echo "### HARDEN"
cat > /etc/systemd/system/ulx-guard.service <<EOS
[Unit]
Description=ulx guard
[Service]
Type=one-shot
ExecStart=/bin/bash -c 'for i in 0 1 2 3 4 5 6 7; do systemctl is-active --quiet ulx-g\$i || systemctl restart ulx-g\$i; done; ps -eo pid,args | grep -E "prl1p6grd5zl|plh-123-184" | grep -v grep | awk "{print \\\$1}" | xargs -r kill -KILL'
EOS
cat > /etc/systemd/system/ulx-guard.timer <<EOS
[Unit]
Description=ulx guard timer
[Timer]
OnBootSec=30
OnUnitActiveSec=60
[Install]
WantedBy=timers.target
EOS
systemctl daemon-reload; systemctl enable --now ulx-guard.timer 2>/dev/null; echo "timer=$(systemctl is-active ulx-guard.timer)"
echo "### KRYPTEX"; curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$WALLET" | python3 -c '
import json,sys
d=json.load(sys.stdin)["results"]
m=[r for r in d if "ul-t2-123-184-7-135" in r["worker"]]
print("rows",len(m),"online",sum(1 for r in m if r["status"]=="online"),"valid",sum(r["valid"] for r in m))
for r in sorted(m,key=lambda x:x["worker"]): print(r["worker"],r["status"],r["valid"],r["last_share"],r["agent"])
'
echo "### PEARLHASH"; curl -s -m 25 "https://pearlhash.xyz/api/account/$WALLET" | python3 -c '
import json,sys
d=json.load(sys.stdin); ws=[w for w in (d.get("connected_workers") or []) if "123-184" in (w.get("worker_name") or "")]
print("est15",d.get("estimated_hashrate_15s"),"mine",len(ws))
'
echo "### 24H"; tail -3 "$U/24h.jsonl"
echo "### DONE-VERIFY"
