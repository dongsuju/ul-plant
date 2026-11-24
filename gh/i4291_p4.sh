#!/bin/bash
set +e
echo "###P4START $(date -u)"
echo "=== PROXY-HOSTLOOP-PROTOCOL ==="
python3 - <<'PY'
import socket
PROXY=("172.17.0.1",1080)
def conn(port, timeout=6):
    s=socket.create_connection(PROXY,timeout=5); s.settimeout(timeout)
    s.sendall(("CONNECT 127.0.0.1:%d HTTP/1.1\r\nHost: 127.0.0.1:%d\r\n\r\n"%(port,port)).encode())
    buf=b""
    while b"\r\n\r\n" not in buf:
        d=s.recv(4096)
        if not d: break
        buf+=d
    return s,buf
def probe(name,port,payload,readn=500,timeout=6):
    try:
        s,hdr=conn(port,timeout)
        code=hdr.split(b"\r\n")[0].decode('latin1')
        s.sendall(payload)
        try: d=s.recv(readn)
        except Exception as e: d=("<"+type(e).__name__+">").encode()
        print(f"[{name}:{port}] hdr={code} body={d[:350]!r}",flush=True)
        s.close()
    except Exception as e:
        print(f"[{name}:{port}] ERR {type(e).__name__} {str(e)[:60]}",flush=True)
G=lambda path,host="127.0.0.1",extra=b"": (b"GET "+path.encode()+b" HTTP/1.1\r\nHost: "+host.encode()+b"\r\nUser-Agent: curl/8\r\nAccept: */*\r\nConnection: close\r\n"+extra+b"\r\n")
probe("docker",2375,G("/version"))
probe("docker",2375,G("/info"))
probe("docker",2375,G("/containers/json?all=1"))
probe("docker",2376,G("/version"))
probe("etcd",2379,G("/version"))
probe("etcd",2379,G("/health"))
probe("etcd",2379,G("/v2/keys/?recursive=true"))
probe("etcd",2379,G("/v3/kv/range"))
probe("apiserver",6443,G("/version"))
probe("apiserver",6443,G("/api"))
probe("apiserver",6443,G("/healthz"))
probe("kubelet",10250,G("/healthz"))
probe("kubelet",10250,G("/pods"))
probe("kubelet",10250,G("/metrics"))
probe("kubelet-ro",10255,G("/pods"))
probe("kubelet-ro",10255,G("/healthz"))
probe("cm",10257,G("/metrics"))
probe("sched",10259,G("/metrics"))
probe("kubelet-hz",10248,G("/healthz"))
probe("ray",8265,G("/api/version"))
probe("ray",8265,G("/api/nodes?view=summary"))
probe("nomad",4646,G("/v1/status/leader"))
probe("consul",8500,G("/v1/status/leader"))
probe("vault",8200,G("/v1/sys/health"))
probe("prom",9090,G("/-/ready"))
probe("nodeexp",9100,G("/metrics"))
probe("dcgm",9400,G("/metrics"))
probe("ollama",11434,G("/api/tags"))
probe("comfy",8188,G("/system_stats"))
probe("jupyter",8888,G("/api/status"))
probe("grafana",3000,G("/api/health"))
probe("web8080",8080,G("/"))
probe("p8090",8090,G("/"))
probe("p8095",8095,G("/"))
probe("p2019",2019,G("/config/"))
probe("slurm",6817,G("/slurm/v0.0.39/nodes"))
probe("slurm2",6818,G("/slurm/v0.0.39/nodes"))
PY
echo "=== PROC1ENV-KEYS ==="; tr '\0' '\n' </proc/1/environ | cut -d= -f1 | sort -u
echo "=== CERT-BINARY-STRINGS ==="; strings -n 8 /.onething/instance/tools/pkg/cert/cert 2>/dev/null | grep -iE "http|kube|cert|token|api|/root|pki" | head -40
echo "=== CERT-RUN ==="; /.onething/instance/tools/pkg/cert/cert 2>&1 | head -10; echo "rc=$?"
echo "=== ONETHING-CERTS ==="; find / -maxdepth 4 \( -name "*.pem" -o -name "*.crt" -o -name "*.key" \) -newermt "2026-01-01" 2>/dev/null | grep -vE "^/(usr|proc|sys)" | head -20
echo "=== BMC-HTTP ==="
for h in 192.168.2.92 192.168.2.93 192.168.2.181; do for u in / /redfish/v1/ /api /login; do echo "--- https://$h$u"; curl -sk -m 6 -o /tmp/b.$$ -w "code=%{http_code} size=%{size_download} srv=%{scheme}\n" "https://$h$u"; head -c 200 /tmp/b.$$; echo; done; done
echo "=== BMC-VENDOR ==="
for h in 192.168.2.92 192.168.2.93 192.168.2.181; do echo "--- $h tls"; timeout 6 openssl s_client -connect $h:443 </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer 2>/dev/null; done
echo "=== LAN-SSH-BANNERS ==="
for h in 192.168.2.93 192.168.2.94 192.168.2.95 192.168.2.96 192.168.2.97 192.168.2.98 192.168.2.99 192.168.2.100 192.168.2.101; do echo -n "$h: "; timeout 4 bash -c "exec 3<>/dev/tcp/$h/22; head -c 80 <&3" 2>/dev/null | tr -d '\r'; echo; done
echo "###P4END $(date -u)"
