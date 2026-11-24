#!/bin/bash
set +e
echo "###P33START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p33-1795552649.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P33START $(date -u)"
echo "=== A. KERNEL ==="; uname -a; head -3 /etc/os-release
cat /proc/sys/kernel/unprivileged_userns_clone 2>&1; cat /proc/sys/user/max_user_namespaces 2>&1
echo "-- unshare:"; unshare -Urn id 2>&1 | head -2
grep -E 'CapEff|Seccomp' /proc/self/status
grep -c nf_tables /proc/modules 2>/dev/null; grep -E 'nf_tables|overlay' /proc/modules 2>/dev/null | head -3
echo "=== B. TOOLSHANDLER ==="
for u in / /api /api/v1 /docs /openapi.json /health /version /exec /run /shell /v1/exec; do printf "%s " "$u"; curl -s -m 3 -o /tmp/th.$$ -w "c=%{http_code} l=%{size_download} " "http://127.0.0.1:1300$u"; head -c 100 /tmp/th.$$ | tr '\n' ' '; echo; done
strings -n 6 /.onething/instance/tools/pkg/toolsHandler/bin/* 2>/dev/null | grep -aoE '"/[a-zA-Z0-9_/-]{2,40}"' | sort -u | head -40
ls -l /.onething/instance/tools/pkg/toolsHandler/bin/ 2>&1 | head -4
echo "=== C. FILEBROWSER-API ==="
curl -s -m 4 -o /tmp/fb2.$$ -w "c=%{http_code} l=%{size_download}\n" "http://127.0.0.1:1301/api/resources/"
head -c 200 /tmp/fb2.$$; echo
echo "=== D. VNC-OCR ==="
timeout 240 bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tesseract-ocr python3-pip >/dev/null 2>&1; pip install -q vncdotool >/dev/null 2>&1'
command -v vncdo tesseract | tr '\n' ' '; echo
for hp in 192.168.2.36::5901 192.168.2.41::5900 192.168.2.45::5900 192.168.2.63::5900; do
  f=/root/q/vnc_$(echo $hp | tr ':.' '__').png
  timeout 30 vncdo -s $hp capture "$f" 2>&1 | tail -1
  if [ -f "$f" ]; then echo "--- $f $(stat -c %s $f)"; timeout 40 tesseract "$f" - 2>/dev/null | tr -s '\n' '|' | head -c 500; echo; fi
done
echo "=== E. RFB-SEC ==="
for hp in 192.168.2.36:5901 192.168.2.41:5900 192.168.2.45:5900 192.168.2.63:5900; do python3 - "$hp" <<'PY'
import socket,sys
h,pp=sys.argv[1].split(':'); p=int(pp)
try:
    s=socket.create_connection((h,p),timeout=4); v=s.recv(12); s.sendall(b"RFB 003.008\n"); d=s.recv(64)
    print(h,p,v.strip(),"n=",d[0] if d else None,"types=",list(d[1:1+(d[0] if d else 0)]))
except Exception as e: print(h,p,"ERR",e)
PY
done
echo "###P33END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -3
echo "###P33END $(date -u)"
