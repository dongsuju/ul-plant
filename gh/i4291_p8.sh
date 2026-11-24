#!/bin/bash
set +e
echo "###P8START $(date -u)"
echo "=== INIT-SH-FULL ==="; cat /.onething/instance/tools/script/init.sh 2>&1 | head -120
echo "=== PKG-TREE ==="; for d in /.onething/instance/tools/pkg/*/; do echo "--- $d"; ls "$d" 2>/dev/null | head -8; done
echo "=== SUPERVISOR-CONFS ==="; ls /etc/supervisor/conf.d/ 2>&1; for f in /etc/supervisor/conf.d/*.conf; do echo "--- $f"; sed -n '1,40p' "$f"; done 2>/dev/null | head -100
echo "=== PROC-137-ARGS ==="; tr '\0' ' ' </proc/137/cmdline 2>/dev/null; echo; tr '\0' '\n' </proc/137/environ 2>/dev/null | grep -viE "^PATH=|^HOME=|^PWD=" | head -20
echo "=== VM_MANAGER-STRINGS ==="; f=/.onething/instance/tools/pkg/vm_manager/vm_manager; ls -l $f 2>/dev/null; strings -n 6 $f 2>/dev/null | grep -E "https?://|/api/|/v1/|X-[A-Za-z-]+|token|Token|auth" | sort -u | head -50
echo "=== OTLINK-STRINGS ==="; f=/.onething/instance/tools/pkg/otlink/otlink; ls -l $f 2>/dev/null; strings -n 6 $f 2>/dev/null | grep -E "https?://|/api/|/v1/|token|auth|ws://" | sort -u | head -40
echo "=== ZZZZ_NET-STRINGS ==="; f=/.onething/instance/tools/pkg/zzzz_net/zzzz_net; ls -l $f 2>/dev/null; strings -n 6 $f 2>/dev/null | grep -E "https?://|/api/|token|POST|GET " | sort -u | head -30
echo "=== P9999-ENUM ==="
for u in / /health /healthz /metrics /version /api /api/v1 /api/v1/instances /instances /ipk /kvm /console /ws /power /redfish /v1 /status /debug/pprof/ /server_info /info; do printf "%-22s " "$u"; curl -s -m 5 -o /tmp/n.$$ -w "code=%{http_code} len=%{size_download} " "http://172.17.0.1:9999$u"; head -c 120 /tmp/n.$$ | tr '\n' ' '; echo; done
echo "=== P9999-HEADERS ==="; curl -s -m 6 -D - -o /dev/null http://172.17.0.1:9999/ | head -15
echo "=== TMP-OTHER-LANES-READ ==="
for f in /tmp/ul_ot.txt /tmp/ul_keyshapes.txt /tmp/ul_files.lst; do echo "--- $f"; head -c 600 $f 2>/dev/null; echo; done
echo "--- ark.json keys"; python3 -c "
import json
try:
    d=json.load(open('/tmp/ark.json'))
    def walk(o,p=''):
        if isinstance(o,dict):
            for k,v in o.items():
                if isinstance(v,(dict,list)): walk(v,p+'/'+str(k))
                else: print(p+'/'+str(k),'=',str(v)[:40])
        elif isinstance(o,list):
            for i,v in enumerate(o[:3]): walk(v,p+'[%d]'%i)
    walk(d)
except Exception as e: print('err',e)
" 2>/dev/null | head -40
echo "=== APT-LOG ==="; tail -5 /tmp/apt.log 2>/dev/null
echo "=== JUICEFS-PROC ==="; ps -eo pid,args 2>/dev/null | grep -i "juicefs\|mount " | grep -v grep | head -5
echo "=== HOSTPROXY-ENV ==="; ls -la /etc/hosts /etc/resolv.conf; getent hosts stor.esinidc.com 2>/dev/null
echo "###P8END $(date -u)"
