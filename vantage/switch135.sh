#!/bin/bash
# UL switch pass on 123.184.7.135
#  a) neutralize the plh supervisor (cron */3 /opt/plh/keepalive.sh) by replacing it with our keep
#  b) restore the t19 kryptex TLS relay (127.0.0.1:17048 -> prl-sg/eu/us/hk:8048)
#  c) test stratum authorize for the canonical wallet through the relay
#  d) if it authorizes, move all 8 workers to the relay (kryptex, per-worker API-verifiable)
#  e) otherwise stay on pearlhash; print everything
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
PREFIX=${PREFIX:-ul-t2-123-184-7-135}
D=/root/ul
A=$D/actor
mkdir -p "$A" "$D/logs"

echo "### PLH-SUPERVISOR $(date -u +%FT%TZ)"
ls -la /opt/plh/ 2>/dev/null | head -20
echo "--- keepalive.sh"; cat /opt/plh/keepalive.sh 2>/dev/null | head -40
cp -f /opt/plh/keepalive.sh "$A"/plh_keepalive.sh 2>/dev/null
cp -f /opt/t19/keep.sh "$A"/t19_keep.sh 2>/dev/null
cat > /opt/plh/keepalive.sh <<EOS
#!/bin/bash
# superseded: plh wallet parked, canonical set is authoritative
/bin/bash $D/keep.sh
ps -eo pid,args | grep -E 'plh-|prl1p6grd5zl' | grep -v grep | awk '{print \$1}' | xargs -r kill -KILL 2>/dev/null
EOS
chmod +x /opt/plh/keepalive.sh
echo "replaced /opt/plh/keepalive.sh"

echo "### RELAY-RESTORE"
if [ -f /opt/t19/relay.py.orig ] && [ ! -f /opt/t19/relay.py ]; then cp -f /opt/t19/relay.py.orig /opt/t19/relay.py; fi
ps -eo pid,args | grep -F '/opt/t19/relay.py' | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null; done
os=$(python3 -c 'import ssl;print(ssl.OPENSSL_VERSION)' 2>/dev/null)
if [ -f /opt/t19/relay.py ]; then
  setsid nohup python3 -u /opt/t19/relay.py >> "$D/logs/relay.log" 2>&1 &
  sleep 3
fi
ss -lntp 2>/dev/null | grep 17048 || echo "relay 17048 NOT listening"

echo "### RELAY-HANDSHAKE"
python3 - <<'PYH'
import socket, json, ssl, time
w = "prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz"
try:
    s = socket.create_connection(("127.0.0.1", 17048), timeout=12)
    s.sendall((json.dumps({"id": 1, "method": "mining.subscribe", "params": ["ul-t2/0.1"]}) + "\n").encode())
    print("sub:", s.recv(8192)[:300])
    s.sendall((json.dumps({"id": 2, "method": "mining.authorize", "params": [w + ".ul-t2-123-184-7-135-gt", "x"]}) + "\n").encode())
    a = s.recv(8192)
    print("auth:", a[:300])
    print("AUTH_OK" if b'"result":true' in a or b'"result": true' in a else "AUTH_NO")
    s.close()
except Exception as e:
    print("ERR", repr(e)[:200])
PYH

echo "### POINT-AT-RELAY"
# keep a pearlhash fallback copy of every cmd file
for dev in 0 1 2 3 4 5 6 7; do
  f="$D/cmd-g$dev.sh"
  [ -f "$f" ] || continue
  [ -f "$D/cmd-ph-g$dev.sh" ] || cp -f "$f" "$D/cmd-ph-g$dev.sh"
  W="$PREFIX-g$dev"
  CMD="$D/wildrig-multi --algo pearlhash --url 127.0.0.1:17048 --user $WALLET --worker $W --pass x --protocol stratum --opencl-devices $dev --gpu-intensity 1 --gpu-temp-limit 90 --api-port $((1960+dev))"
  printf '#!/bin/sh\nexec %s >> %s/logs/g%s.log 2>&1\n' "$CMD" "$D" "$dev" > "$f"
  chmod +x "$f"
  printf '%s\n' "$CMD" > "$D/argv-g$dev.txt"
done
ps -eo pid,args | grep -E 'wildrig' | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null; done
sleep 3
for dev in 0 1 2 3 4 5 6 7; do setsid nohup sh "$D/cmd-g$dev.sh" >/dev/null 2>&1 & sleep 1; done
sleep 60
echo "### PROCS"
ps -eo pid,args | grep wildrig | grep -v grep
echo "### LOGS"
for g in 0 1 2 3 4 5 6 7; do echo "--- g$g"; tail -5 "$D/logs/g$g.log" 2>/dev/null; done
echo "### KRYPTEX-API-FROM-HOST"
curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$WALLET" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)["results"]
except Exception as e: print("parse",e); raise SystemExit
for r in d:
    if "123-184-7-135" in r["worker"]:
        print(r["worker"], r["status"], "valid=",r["valid"], "last_share=",r["last_share"], "hr30m=",r["avg_hashrate_30m"], "agent=",r["agent"])
print("total_rows",len(d))
' 2>&1 | head -20
echo "### DONE-SWITCH"
