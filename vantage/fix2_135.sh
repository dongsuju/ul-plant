#!/bin/bash
# UL fix2: kill the plh krig systemd template set, restore our pearlhash canonical set on all 8 GPUs,
# install the 24h sampler. Verify with a fresh pool API read from the host itself.
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
PREFIX=${PREFIX:-ul-t2-123-184-7-135}
D=/root/ul
A=$D/actor
mkdir -p "$A" "$D/logs"

echo "### PLH-UNITS $(date -u +%FT%TZ)"
systemctl list-units --all --no-pager 2>/dev/null | grep -i plh
for u in $(systemctl list-unit-files --no-pager 2>/dev/null | awk '/plh/{print $1}'); do echo "--- $u"; systemctl cat "$u" 2>/dev/null | head -30; cp -f "/etc/systemd/system/$u" "$A"/ 2>/dev/null; done
echo "### PLH-STOP-MASK"
for i in 0 1 2 3 4 5 6 7; do
  systemctl stop "plh-card@$i" 2>/dev/null
  systemctl disable "plh-card@$i" 2>/dev/null
  systemctl mask "plh-card@$i" 2>/dev/null
done
ps -eo pid,args | grep -E 'krig-miner|plh-|prl1p6grd5zl' | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null && echo "kill-plh $p"; done
sleep 2

echo "### RESTORE-PEARLHASH-CMDS"
for dev in 0 1 2 3 4 5 6 7; do
  if [ -f "$D/cmd-ph-g$dev.sh" ]; then cp -f "$D/cmd-ph-g$dev.sh" "$D/cmd-g$dev.sh"; fi
  W="$PREFIX-g$dev"
  CMD="$D/wildrig-multi --algo pearlhash --url pool.pearlhash.xyz:9000 --user $WALLET --worker $W --pass x --protocol stratum --opencl-devices $dev --gpu-intensity 1 --gpu-temp-limit 90 --api-port $((1960+dev))"
  printf '#!/bin/sh\nexec %s >> %s/logs/g%s.log 2>&1\n' "$CMD" "$D" "$dev" > "$D/cmd-g$dev.sh"
  chmod +x "$D/cmd-g$dev.sh"
done
ps -eo pid,args | grep -E 'wildrig|krig-miner' | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null; done
sleep 3
for dev in 0 1 2 3 4 5 6 7; do setsid nohup sh "$D/cmd-g$dev.sh" >/dev/null 2>&1 & sleep 1; done

echo "### KEEP"
cat > "$D/keep.sh" <<EOS
#!/bin/bash
D=$D
PREFIX=$PREFIX
for f in \$D/cmd-g*.sh; do
  [ -f "\$f" ] || continue
  W="\$PREFIX-g\$(basename "\$f" | sed 's/cmd-g\(.*\)\.sh/\1/')"
  pgrep -f -- "--worker \$W" >/dev/null 2>&1 || setsid nohup sh "\$f" >/dev/null 2>&1 &
done
ps -eo pid,args | grep -E 'krig-miner|plh-|prl1p6grd5zl' | grep -v grep | awk '{print \$1}' | xargs -r kill -KILL 2>/dev/null
EOS
chmod +x "$D/keep.sh"
systemctl restart ul-pearl-keep 2>/dev/null; echo "unit=$(systemctl is-active ul-pearl-keep 2>/dev/null)"

echo "### SAMPLER"
cat > "$D/sample.sh" <<EOS
#!/bin/bash
W=$WALLET
curl -s -m 20 "https://pearlhash.xyz/api/account/\$W" -o /tmp/pha.\$\$.json
printf '%s ' "\$(date -u +%FT%TZ)" >> $D/24h.jsonl
python3 -c '
import json,sys
try:
  d=json.load(open(sys.argv[1]))
except Exception as e:
  print("parse_err",e); raise SystemExit
ws=[w for w in (d.get("connected_workers") or []) if "123-184" in (w.get("worker_name") or "")]
print(json.dumps({"est15":d.get("estimated_hashrate_15s"),"workers":len(ws),"names":[w["worker_name"] for w in ws]}))
' /tmp/pha.\$\$.json >> $D/24h.jsonl 2>/dev/null
rm -f /tmp/pha.\$\$.json
EOS
chmod +x "$D/sample.sh"
( crontab -l 2>/dev/null | grep -v 'ul/sample.sh'; echo "@reboot /bin/bash $D/keep.sh >/dev/null 2>&1"; echo "*/5 * * * * /bin/bash $D/keep.sh >/dev/null 2>&1"; echo "*/10 * * * * /bin/bash $D/sample.sh >/dev/null 2>&1" ) | crontab - 2>/dev/null
/bin/bash "$D/sample.sh"

sleep 60
echo "### PROCS"
ps -eo pid,args | grep -E 'wildrig|krig-miner' | grep -v grep
echo "### GPU"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader
echo "### ACCEPTED"
for g in 0 1 2 3 4 5 6 7; do printf 'g%s: ' $g; grep -aE 'accepted' "$D/logs/g$g.log" 2>/dev/null | tail -1; done
echo "### POOL-FROM-HOST"
curl -s -m 25 "https://pearlhash.xyz/api/account/$WALLET" | python3 -c '
import json,sys
d=json.load(sys.stdin); ws=d.get("connected_workers") or []
mine=[w for w in ws if "123-184" in (w.get("worker_name") or "")]
print("est15",d.get("estimated_hashrate_15s"),"mine",len(mine))
for w in mine: print(w.get("worker_name"), w.get("version"))
'
echo "### 24H"; cat "$D/24h.jsonl" 2>/dev/null | tail -3
echo "### DONE-FIX2"
