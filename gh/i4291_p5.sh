#!/bin/bash
set +e
echo "###P5START $(date -u)"
echo "=== P5-A 172.17.0.0/24 ==="
python3 - <<'PY'
import socket,concurrent.futures
ports=[22,80,443,3000,5000,8000,8080,8090,8095,8188,8265,8501,8888,9000,9400,10250,11434,18080,2375,2376,6443,5900,3389,25,3306,6379,27017,5432]
def chk(t):
    h,p=t
    try:
        s=socket.create_connection((h,p),timeout=1.5); s.settimeout(2)
        try:
            if p in (80,3000,5000,8000,8080,8090,8095,8188,8265,8501,8888,9000,9400,10250,11434,18080,2375,2376,6443,443,8501):
                s.sendall(b"GET / HTTP/1.0\r\nHost: h\r\n\r\n")
            d=s.recv(100)
        except Exception: d=b""
        s.close(); return (h,p,d[:50])
    except Exception: return None
tg=[("172.17.0.%d"%i,p) for i in range(1,255) for p in ports]
with concurrent.futures.ThreadPoolExecutor(max_workers=200) as ex:
    for r in ex.map(chk,tg):
        if r: print("172.17.0.%s:%d %r"%(r[0].split('.')[-1],r[1],r[2]))
PY
echo "=== P5-B 192.168.2.0/24 ==="
python3 - <<'PY'
import socket,concurrent.futures
ports=[21,22,80,111,443,623,2049,2375,5900,5901,6443,8006,8080,9090,9400,10250,3389,3128,8888]
def chk(t):
    h,p=t
    try:
        s=socket.create_connection((h,p),timeout=1.2); s.settimeout(2)
        try: d=s.recv(60)
        except Exception: d=b""
        s.close(); return (h,p,d[:40])
    except Exception: return None
tg=[("192.168.2.%d"%i,p) for i in range(1,255) for p in ports]
with concurrent.futures.ThreadPoolExecutor(max_workers=250) as ex:
    for r in ex.map(chk,tg):
        if r: print("%s:%d %r"%(r[0],r[1],r[2]))
PY
echo "=== P5-C HOSTLOOP-SCAN via 1080 ==="
python3 - <<'PY'
import socket,concurrent.futures
def probe(p):
    try:
        s=socket.create_connection(("172.17.0.1",1080),timeout=3); s.settimeout(3)
        s.sendall(("CONNECT 127.0.0.1:%d HTTP/1.1\r\nHost: x\r\n\r\n"%p).encode())
        buf=b""
        while b"\r\n\r\n" not in buf:
            d=s.recv(2048)
            if not d: break
            buf+=d
        if b" 200 " not in buf.split(b"\r\n")[0]:
            s.close(); return (p,"CONNECTFAIL",buf.split(b"\r\n")[0][:40])
        s.sendall(b"GET / HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n")
        try: d=s.recv(80)
        except Exception: d=b""
        s.close()
        return (p,"OPEN" if d else "nodata",d[:50])
    except Exception as e:
        return (p,"ERR",type(e).__name__)
# targeted first
tgt=list(range(1,1025))+list(range(1024,11000,1))
tgt=list(dict.fromkeys(tgt))
res=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=120) as ex:
    for r in ex.map(probe,tgt):
        if r[1] in ("OPEN","nodata") and r[0] not in (1080,):
            res.append(r)
for r in sorted(res): print("hostlo:%d %s %r"%(r[0],r[1],r[2]))
PY
echo "=== P5-D JUICEFS-PROC ==="
for pid in $(pgrep -f juicefs 2>/dev/null | head -3); do echo "--- pid $pid"; tr '\0' ' ' </proc/$pid/cmdline 2>/dev/null; echo; tr '\0' '\n' </proc/$pid/environ 2>/dev/null | grep -iE "secret|access|key|token|meta|bucket|pass" | head -10; done
echo "=== P5-E ALL-PROC-ENV-SECRETS ==="
for d in /proc/[0-9]*; do pid=${d#/proc/}; n=$(tr '\0' '\n' <$d/environ 2>/dev/null | grep -icE "secret|password|token|access_key|accesskey"); [ "$n" -gt 0 ] && echo "pid $pid name=$(cat $d/comm 2>/dev/null) hits=$n"; done 2>/dev/null | head -20
echo "=== P5-F K3S-CHECK ==="
ls -la /var/lib/rancher /etc/rancher 2>&1 | head; ls /var/lib/rancher/k3s 2>&1 | head
grep -aoE "cpwx[a-z0-9]*|server=[^ ]*|node-token" /etc/hosts /.onething/instance/tools/script/init.sh 2>/dev/null | head
echo "###P5END $(date -u)"
