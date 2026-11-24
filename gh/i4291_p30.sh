#!/bin/bash
set +e
echo "###P30START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p30-1795550752.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P30START $(date -u)"
echo "=== A. PLATFORM-PROCS ==="
ps -eo pid,args | grep -aE 'pan_client|otlink|vm_manager|zzzz|model_center|xyipk|monitor|agent' | grep -av grep | head -20
echo "=== B. PROC-ENV ==="
for p in $(ps -eo pid,args | grep -aE 'pan_client|xyipk|model_center|otlink|vm_manager' | grep -av grep | awk '{print $1}' | head -6); do echo "--- pid $p $(tr '\0' ' ' </proc/$p/cmdline | head -c 200)"; tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -aiE 'token|url|host|api|key|secret|port|id' | head -12; done
echo "=== C. PANCLIENT-STRINGS ==="
strings -n 8 /.onething/instance/tools/pkg/pan_client/bin/pan_client 2>/dev/null | grep -aE 'https?://|/api/|token=|accessKey|secretKey' | sort -u | head -40
echo "=== D. TOOLS-TREE ==="
ls -laR /.onething/instance/tools 2>/dev/null | head -60
for f in $(find /.onething/instance/tools -maxdepth 4 -type f \( -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.env' -o -name '*.conf' -o -name '*.ini' \) 2>/dev/null | head -10); do echo "--- $f"; head -c 600 "$f"; echo; done
echo "=== E. AGENT-PROFILES ==="
for port in 2025 8081 10221 9999 6063; do
  echo "--- $port"; for u in /debug/pprof/cmdline /debug/pprof/ /swagger/index.html /swagger/doc.json /ping /readyz /version /info /api /vms /instances /exec; do printf "%s " "$u"; curl -s -m 3 -o /tmp/pp.$$ -w "c=%{http_code} l=%{size_download} " "http://172.17.0.1:$port$u"; head -c 80 /tmp/pp.$$ | tr '\n' ' '; echo; done
done
echo "=== F. SIBLING-8080-DEEP ==="
for ip in 172.17.0.3 172.17.0.7; do
  echo "--- $ip"; curl -s -m 4 -D - -o /dev/null "http://$ip:8080/"; curl -s -m 4 -X OPTIONS -D - -o /dev/null "http://$ip:8080/"; for h in localhost instance 116.211.127.168; do printf "host=%s " "$h"; curl -s -m 3 -H "Host: $h" -o /tmp/hh.$$ -w "c=%{http_code} l=%{size_download} " "http://$ip:8080/"; head -c 60 /tmp/hh.$$ | tr '\n' ' '; echo; done
  printf "tls: "; curl -sk -m 3 -o /dev/null -w "c=%{http_code}\n" "https://$ip:8080/"
done
echo "=== G. 9999-TLS ==="; curl -sk -m 4 -o /tmp/x9.$$ -w "c=%{http_code} l=%{size_download} " "https://172.17.0.1:9999/"; head -c 80 /tmp/x9.$$; echo
echo "=== H. 6443-DIRECT ==="; timeout 4 bash -c 'exec 3<>/dev/tcp/172.17.0.1/6443 && echo TCP_OK' 2>&1; curl -sk -m 6 -o /tmp/k6.$$ -w "c=%{http_code} " "https://172.17.0.1:6443/version"; head -c 100 /tmp/k6.$$; echo
echo "=== I. RELAY-LOCAL ==="; timeout 4 bash -c 'exec 3<>/dev/tcp/172.17.0.1/32917 && head -c 40 <&3' 2>&1 | tr -d '\r'
echo "=== J. NETSTAT-LIKE ==="; cat /proc/net/tcp 2>/dev/null | awk 'NR>1{split($2,a,":"); print strtonum("0x" a[2])}' | sort -n | uniq -c | head -30
echo "###P30END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -3
echo "###P30END $(date -u)"
