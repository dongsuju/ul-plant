#!/bin/bash
set +e
echo "###P39START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p39-1795553947.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P39START $(date -u)"
echo "===== P34 LOG (full portscan) ====="
head -c 5000 /root/q/p34-1795552882.log 2>&1
echo; echo "===== MONITORING-PORT-SWEEP ====="
python3 - <<'PY'
import socket,concurrent.futures as cf
ports=[8428,8481,9090,9093,3000,3100,16686,9091,8080,80,443,22,5900,6443,2375,10250,9400,11434,8888,8000,9095,9100,9269,9115]
def t(a):
    ip,p=a
    s=socket.socket(); s.settimeout(0.6)
    try: s.connect((ip,p)); return (ip,p)
    except Exception: return None
    finally: s.close()
jobs=[("192.168.%d.%d"%(seg,i),p) for seg in (1,2) for i in range(1,255) for p in ports]
res=[]
with cf.ThreadPoolExecutor(max_workers=400) as ex:
    for r in ex.map(t,jobs):
        if r: res.append(r)
for ip,p in sorted(res): print("MO",ip,p)
PY
echo "===== VM-QUERY-TESTS ====="
for hp in 192.168.2.45:8428 192.168.2.63:8428 192.168.2.45:9090 192.168.2.63:9090 192.168.2.45:3000 192.168.2.63:3000; do h=${hp%%:*}; p=${hp##*:}; printf "%s " "$hp"; curl -s -m 4 -o /tmp/q.$$ -w "c=%{http_code} l=%{size_download} " "http://$h:$p/api/v1/targets" 2>/dev/null; head -c 80 /tmp/q.$$ | tr '\n' ' '; echo; done
echo "###P39END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -2
echo "###P39END $(date -u)"
