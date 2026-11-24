#!/bin/bash
set +e
echo "###P9START $(date -u)"
echo "=== HOSTLOOP-SERVICES ==="
for port in 9999 8429 9100 2023 2025 6063 8081 10221 123; do
  for u in / /health /healthz /metrics /version /debug/pprof/ /api /api/v1 /status /info /server_info /config; do
    out=$(curl -s -x http://172.17.0.1:1080 -m 5 -o /tmp/z.$$ -w "c=%{http_code} l=%{size_download}" "http://127.0.0.1:$port$u" 2>/dev/null)
    b=$(head -c 100 /tmp/z.$$ 2>/dev/null | tr '\n' ' ')
    case "$out" in *"c=000"*) ;; *) echo "$port$u [$out] $b";; esac
  done
done
echo "=== HOSTLOOP-HEADERS ==="
for port in 9999 8429 9100 2023 2025 6063 8081 10221; do echo "--- $port"; curl -s -x http://172.17.0.1:1080 -m 5 -D - -o /dev/null "http://127.0.0.1:$port/" 2>/dev/null | head -8; done
echo "=== VNC-192.168.2 ==="
python3 - <<'PY'
import socket
for h,p in [("192.168.2.36",5900),("192.168.2.36",5901),("192.168.2.41",5900),("192.168.2.45",5900),("192.168.2.63",5900),("192.168.2.63",5901)]:
    try:
        s=socket.create_connection((h,p),timeout=4); s.settimeout(5)
        v=s.recv(12); print(h,p,"ver",v)
        s.sendall(b"RFB 003.008\n")
        d=s.recv(64); print("  sectypes",d[:32].hex(),d[:32])
        s.close()
    except Exception as e: print(h,p,"ERR",type(e).__name__)
PY
echo "=== BMC-RF-DETAIL ==="
for h in 192.168.2.83 192.168.2.90 192.168.2.92 192.168.2.93 192.168.2.181; do echo "--- $h"; curl -sk -m 6 "https://$h/redfish/v1/" 2>/dev/null | head -c 400; echo; curl -sk -m 6 "https://$h/redfish/v1/Managers" 2>/dev/null | head -c 250; echo; done
echo "=== LAN-HTTP-TITLES ==="
for h in 192.168.2.36 192.168.2.41 192.168.2.45 192.168.2.63 192.168.2.94 192.168.2.101; do echo "--- $h"; curl -s -m 5 -o /tmp/l.$$ -w "c=%{http_code} " "http://$h/"; head -c 150 /tmp/l.$$ | tr '\n' ' '; echo; curl -sk -m 5 -o /tmp/l2.$$ -w "tls_c=%{http_code} " "https://$h/"; head -c 120 /tmp/l2.$$ | tr '\n' ' '; echo; done
echo "=== RSYNCD-MODULE ==="
python3 - <<'PY'
import socket
try:
    s=socket.create_connection(("172.17.0.1",1080),timeout=5); s.settimeout(8)
    s.sendall(b"CONNECT 127.0.0.1:1234 HTTP/1.1\r\nHost: x\r\n\r\n")
    b=b""
    while b"\r\n\r\n" not in b: b+=s.recv(1)
    s.sendall(b"@RSYNCD: 31.0\n"); print("srv:",s.recv(100))
    s.sendall(b"migrate\n"); print("mod:",s.recv(300))
    s.close()
except Exception as e: print("err",e)
PY
echo "###P9END $(date -u)"
