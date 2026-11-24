#!/bin/bash
set +e
echo "###P1START $(date -u)"
echo "=== IDENTITY ==="; id; hostname; hostname -I 2>/dev/null; uname -a; head -3 /etc/os-release 2>/dev/null
echo "=== CGROUP ==="; cat /proc/1/cgroup; echo "--- self:"; cat /proc/self/cgroup
echo "=== CAPS ==="; grep -E 'CapEff|CapBnd|CapPrm|Seccomp|NoNewPrivs' /proc/self/status; echo "--- pid1:"; grep -E 'CapEff|Seccomp' /proc/1/status
command -v capsh >/dev/null && capsh --print 2>/dev/null | head -15
echo "=== PID1 ==="; tr '\0' ' ' </proc/1/cmdline; echo; ls -l /proc/1/ns 2>/dev/null; echo "--- self ns:"; ls -l /proc/self/ns
echo "=== MOUNTS ==="; mount 2>/dev/null | grep -E ' on / |host|docker|kube|nvidia|onethingai|data1|umer|Umer' | head -40
echo "=== MOUNTINFO-ROOT ==="; grep -E ' / | /etc/hostname| /etc/hosts| /dev/shm| /var/run' /proc/self/mountinfo | head -20
echo "=== SOCKETS ==="; ls -l /var/run/docker.sock /run/docker.sock /run/containerd/containerd.sock /run/k3s/containerd/containerd.sock /var/run/kubelet.sock /run/k0s/containerd.sock 2>&1
echo "=== PROC1ROOT ==="; ls -l /proc/1/root/etc/kubernetes /proc/1/root/var/lib/kubelet /proc/1/root/var/lib/docker /proc/1/root/var/lib/containerd 2>&1 | head -30
echo "=== GPU ==="; nvidia-smi -L 2>&1; echo "devs:"; ls -l /dev/nvidia* 2>&1; echo "count=$(ls /dev/nvidia* 2>/dev/null | wc -l)"; cat /proc/driver/nvidia/version 2>&1
echo "=== HOSTDEV-via-proc1root ==="; ls -l /proc/1/root/dev/nvidia* 2>&1 | head -20; echo "count=$(ls /proc/1/root/dev/nvidia* 2>/dev/null | wc -l)"
echo "=== SYS-NV ==="; ls /sys/class/nvidia* 2>/dev/null | head; ls /proc/driver/nvidia/gpus 2>/dev/null
echo "=== NET ==="; ip route 2>&1; echo; ip -br a 2>&1; echo; cat /etc/hosts; cat /etc/resolv.conf 2>/dev/null | head -6
echo "=== HOSTNAME-MOUNT ==="; ls -l /etc/hostname /etc/hosts 2>&1; stat -c '%d %i %n' /etc/hostname /etc/hosts / 2>&1
echo "=== SA ==="; ls -l /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1; cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null; wc -c /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null
echo "=== PROBE ==="
python3 - <<'PY'
import socket
tg=[("172.17.0.1",2375,"docker2375"),("172.17.0.1",2376,"docker2376"),("172.17.0.1",10250,"kubelet10250"),("172.17.0.1",10255,"kubelet10255"),("172.17.0.1",6443,"apiserver6443"),("172.17.0.1",1080,"prox1080"),("172.17.0.1",22,"host22"),("172.17.0.1",9400,"dcgm9400"),("172.17.0.1",8265,"ray8265")]
for h,p,n in tg:
    try:
        s=socket.create_connection((h,p),timeout=4); s.settimeout(8)
        try:
            d=s.recv(400); print(n,p,"OPEN rcvd",repr(d[:200]))
        except Exception as e: print(n,p,"OPEN norecv",type(e).__name__); s.close()
    except Exception as e:
        print(n,p,"CLOSED",type(e).__name__)
PY
echo "=== HTTP kubelet ==="
for path in /pods /healthz /metrics /stats/summary; do echo "--- 10250$path"; curl -sk -m 8 -o /tmp/r.$$ -w "code=%{http_code} size=%{size_download}\n" "https://172.17.0.1:10250$path"; head -c 300 /tmp/r.$$; echo; done
echo "--- 10255/pods"; curl -s -m 8 -o /tmp/r.$$ -w "code=%{http_code} size=%{size_download}\n" "http://172.17.0.1:10255/pods"; head -c 300 /tmp/r.$$; echo
echo "--- 6443/version"; curl -sk -m 8 -o /tmp/r.$$ -w "code=%{http_code} size=%{size_download}\n" "https://172.17.0.1:6443/version"; head -c 400 /tmp/r.$$; echo
echo "=== docker api ==="
for u in http://172.17.0.1:2375/version http://172.17.0.1:2375/info http://172.17.0.1:2375/containers/json; do echo "--- $u"; curl -s -m 8 -o /tmp/r.$$ -w "code=%{http_code} size=%{size_download}\n" "$u"; head -c 300 /tmp/r.$$; echo; done
echo "=== IMDS quick ==="
for u in http://100.100.100.200/latest/meta-data/instance-id http://100.100.100.200/latest/meta-data/region-id http://169.254.169.254/latest/meta-data/instance-id; do echo "--- $u"; curl -s -m 5 -o /tmp/r.$$ -w "code=%{http_code} size=%{size_download}\n" "$u"; head -c 200 /tmp/r.$$; echo; done
echo "###P1END $(date -u)"
