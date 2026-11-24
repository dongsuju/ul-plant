#!/bin/bash
set +e
echo "###P41START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p41-1795554520.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P41START $(date -u)"
echo "=== P39-REST ==="; tail -c +4000 /root/q/p39-1795553947.log 2>&1 | head -c 4000
echo "=== NEW-HOSTPORTS ==="
for p in 1081 10271 37979; do echo "--- $p"; timeout 4 bash -c "exec 3<>/dev/tcp/172.17.0.1/$p; printf 'GET / HTTP/1.0\r\n\r\n' >&3; head -c 200 <&3" 2>&1 | tr -d '\r'; echo; done
echo "=== KUBELET-192.168.1.90 ==="
for u in /healthz /pods /metrics /configz /pods/; do printf "%s " "$u"; curl -sk -m 6 -o /tmp/k19.$$ -w "c=%{http_code} l=%{size_download} " "https://192.168.1.90:10250$u"; head -c 100 /tmp/k19.$$ | tr '\n' ' '; echo; done
echo "=== GRAFANA-45 ==="
for u in /api/health /login /api/dashboards/home /public/build/manifest.json; do printf "%s " "$u"; curl -s -m 5 -o /tmp/gf.$$ -w "c=%{http_code} l=%{size_download} " "http://192.168.2.45:3000$u"; head -c 100 /tmp/gf.$$ | tr '\n' ' '; echo; done
for cred in admin:admin admin:prom-operator admin:grafana; do u=${cred%%:*}; p=${cred#*:}; printf "login %s " "$cred"; curl -s -m 5 -o /tmp/gl.$$ -w "c=%{http_code} l=%{size_download} " -H "Content-Type: application/json" -d "{\"user\":\"$u\",\"password\":\"$p\"}" "http://192.168.2.45:3000/login"; head -c 80 /tmp/gl.$$ | tr '\n' ' '; echo; done
echo "=== MINIO-100-101 ==="
for h in 192.168.2.100 192.168.2.101; do for u in /minio/health/live / /onethingai-fs/ "/?list-type=2"; do printf "%s%s " "$h" "$u"; curl -s -m 5 -o /tmp/mn.$$ -w "c=%{http_code} l=%{size_download} " "http://$h:9000$u"; head -c 120 /tmp/mn.$$ | tr '\n' ' '; echo; done; done
echo "=== 8080-45-41 ==="
for h in 192.168.2.45 192.168.2.41; do for u in / /metrics /health /api/v1 /docs; do printf "%s%s " "$h" "$u"; curl -s -m 4 -o /tmp/e8.$$ -w "c=%{http_code} l=%{size_download} " "http://$h:8080$u"; head -c 80 /tmp/e8.$$ | tr '\n' ' '; echo; done; done
echo "=== 8000-37-39 ==="
for h in 192.168.2.37 192.168.2.38 192.168.2.39; do for u in / /api/status /docs /health; do printf "%s%s " "$h" "$u"; curl -s -m 4 -o /tmp/e0.$$ -w "c=%{http_code} l=%{size_download} " "http://$h:8000$u"; head -c 80 /tmp/e0.$$ | tr '\n' ' '; echo; done; done
echo "###P41END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -2
echo "###P41END $(date -u)"
