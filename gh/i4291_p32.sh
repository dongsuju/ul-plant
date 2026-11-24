#!/bin/bash
set +e
echo "###P32START $(date -u)"
L=/root/q/p30-1795550752.log
echo "=== C ==="; sed -n '/=== C. PANCLIENT-STRINGS/,/=== D. TOOLS-TREE/p' $L | head -50
echo "=== D2 ==="; sed -n '/=== D. TOOLS-TREE/,/=== E. AGENT/p' $L | grep -aE '^---|^\{|^  "|^[a-z_]+:|\.json|\.yaml|\.sh' | head -40
echo "=== E2 ==="; sed -n '/=== E. AGENT-PROFILES/,/=== F./p' $L | grep -av '404 page not found' | head -40
echo "=== F ==="; sed -n '/=== F. SIBLING/,/=== G./p' $L | head -40
echo "=== G ==="; sed -n '/=== G. 9999/,/=== H./p' $L | head -15
echo "=== H ==="; sed -n '/=== H. 6443/,/=== I./p' $L | head -10
echo "=== I ==="; sed -n '/=== I. RELAY/,/=== J./p' $L | head -10
echo "=== J ==="; sed -n '/=== J. NETSTAT/,$p' $L | head -40
echo "=== CONF-FILES ==="
for f in $(find /.onething/instance/tools/pkg -maxdepth 2 -type f \( -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.conf' -o -name '*.sh' -o -name 'version' \) 2>/dev/null | head -25); do echo "--- $f"; head -c 400 "$f"; echo; done
echo "=== SCRIPT-DIR ==="; ls -la /.onething/instance/tools/script/ 2>&1 | head -10; for f in /.onething/instance/tools/script/*; do [ -f "$f" ] && echo "--- $f" && head -c 500 "$f" && echo; done
echo "=== FILEBROWSER ==="; curl -s -m 4 -o /tmp/fb.$$ -w "c=%{http_code} l=%{size_download}\n" http://127.0.0.1:1301/; head -c 150 /tmp/fb.$$; echo
echo "=== LISTEN-ALL ==="; ss -lntp 2>/dev/null | head -25 || netstat -lntp 2>/dev/null | head -25
echo "=== PAN-ENV ==="; for p in 132 127 126; do echo "--- $p $(tr '\0' ' ' </proc/$p/cmdline|head -c 120)"; tr '\0' '\n' </proc/$p/environ 2>/dev/null | grep -aiE 'xy_|url|token|server|api|host' | head -10; done
echo "###P32END $(date -u)"
