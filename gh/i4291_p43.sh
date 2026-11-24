#!/bin/bash
set +e
echo "###P43START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p43-1795555021.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P43START $(date -u)"
G=http://192.168.2.45:3000
echo "=== ME ==="; curl -s -m 6 -u admin:admin $G/api/user | head -c 300; echo
echo "=== DATASOURCES ==="; curl -s -m 6 -u admin:admin $G/api/datasources -o /root/q/ds.json -w "c=%{http_code} l=%{size_download}\n"; head -c 2500 /root/q/ds.json; echo
echo "=== DS-IDS ==="; python3 - <<'PY'
import json
try:
    d=json.load(open('/root/q/ds.json'))
    for x in d: print(x.get('id'),x.get('uid'),x.get('type'),x.get('name'),x.get('url'),x.get('user'),x.get('basicAuth'),x.get('jsonData',{}).get('httpHeaderName'))
except Exception as e: print('ERR',e)
PY
echo "=== ORG/USERS/PLUGINS ==="
for u in /api/org /api/users /api/plugins /api/admin/stats /api/serviceaccounts/search?perpage=50 /api/annotations?limit=5; do printf "%s " "$u"; curl -s -m 6 -u admin:admin "$G$u" -o /tmp/gq.$$ -w "c=%{http_code} l=%{size_download} "; head -c 150 /tmp/gq.$$ | tr '\n' ' '; echo; done
echo "=== DS-HEALTH ==="
python3 - <<'PY'
import json,subprocess
try:
    d=json.load(open('/root/q/ds.json'))
    for x in d:
        uid=x.get('uid')
        r=subprocess.run(['curl','-s','-m','6','-u','admin:admin','http://192.168.2.45:3000/api/datasources/uid/%s/health'%uid],capture_output=True,text=True)
        print(uid,x.get('type'),r.stdout[:200])
except Exception as e: print('ERR',e)
PY
echo "=== PROM-QUERY ==="
python3 - <<'PY'
import json,subprocess
try:
    d=json.load(open('/root/q/ds.json'))
    for x in d:
        uid=x.get('uid'); t=x.get('type')
        if 'prom' not in (t or '') and 'victoria' not in (t or ''): continue
        body=json.dumps({"queries":[{"refId":"A","expr":"count by (instance) (up)","instant":True,"range":False}],"from":"now-5m","to":"now"})
        r=subprocess.run(['curl','-s','-m','12','-u','admin:admin','-H','Content-Type: application/json','-d',body,'http://192.168.2.45:3000/api/ds/query'],capture_output=True,text=True)
        print('---',uid,t,r.stdout[:1200])
except Exception as e: print('ERR',e)
PY
echo "=== SNIFF-PLUGINS ==="; curl -s -m 6 -u admin:admin "$G/api/plugins?embedded=0" -o /root/q/pl.json -w "c=%{http_code}\n"; python3 -c "
import json
try:
  d=json.load(open('/root/q/pl.json'))
  print([ (p.get('id'),p.get('type'),p.get('enabled')) for p in d ])
except Exception as e: print('ERR',e)
"
echo "###P43END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -2
echo "###P43END $(date -u)"
