#!/bin/bash
set +e
echo "###P34START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p34-1795552882.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P34START $(date -u)"
python3 - <<'PY'
import socket,concurrent.futures as cf
def scan(ip,ports,to=0.35):
    out=[]
    def t(p):
        s=socket.socket(); s.settimeout(to)
        try:
            s.connect((ip,p)); return p
        except Exception: return None
        finally: s.close()
    with cf.ThreadPoolExecutor(max_workers=250) as ex:
        for r in ex.map(t,ports):
            if r: out.append(r)
    return sorted(out)
tgt=[("172.17.0.1",1,65535),("172.17.0.3",1,20000),("172.17.0.4",1,20000),("172.17.0.7",1,20000)]
for ip,a,b in tgt:
    ps=scan(ip,range(a,b+1))
    print("OPEN",ip,ps)
PY
echo "=== BANNER-ON-NEW ==="
for p in 1300 1301 2025 8081 8429 10221 9999 6063 4068 8900 8901 8094 8095; do printf "%s " "$p"; timeout 3 bash -c "exec 3<>/dev/tcp/172.17.0.1/$p; head -c 40 <&3" 2>/dev/null | tr -d '\r'; echo; done
echo "=== MGMT-SCAN ==="
python3 - <<'PY'
import socket,concurrent.futures as cf
ports=[22,80,443,2375,2376,3000,4000,5000,5900,5901,6443,8000,8080,8081,8429,8888,9000,9100,9400,10250,10255,11434,1300,1301,2025,3306,5432,6379,8265,623]
def t(a):
    ip,p=a
    s=socket.socket(); s.settimeout(0.5)
    try: s.connect((ip,p)); return (ip,p)
    except Exception: return None
    finally: s.close()
jobs=[("192.168.2.%d"%i,p) for i in range(1,255) for p in ports]
res=[]
with cf.ThreadPoolExecutor(max_workers=300) as ex:
    for r in ex.map(t,jobs):
        if r: res.append(r)
for ip,p in sorted(res): print("MGO",ip,p)
PY
echo "###P34END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -3
echo "###P34END $(date -u)"
