#!/bin/bash
# BCM plane harvest on g0023 (123.184.7.135) - read-only recon first
export PATH=/cm/local/apps/cmd/sbin:/cm/local/apps/cmd/bin:$PATH
echo "=== ID"; id 2>&1; hostname 2>&1
echo "=== FILES"
for f in /etc/cm.conf /cm/local/apps/cmd/etc/cmd.conf /etc/cm/conf/cm.conf /cm/local/apps/cmd/etc/capabilities.xml; do
  echo "--- $f"; head -c 3000 "$f" 2>&1; echo
done
echo "=== LSETC"; ls -l /cm/local/apps/cmd/etc/ 2>&1 | head -60
echo "=== LSBIN"; ls -l /cm/local/apps/cmd/sbin/ /cm/local/apps/cmd/bin/ 2>&1 | head -80
echo "=== ROOTCM"; ls -la /root/.cm 2>&1 | head -20
for f in /root/.cm/*; do [ -f "$f" ] && { echo "--- $f"; head -c 1200 "$f"; echo; }; done 2>/dev/null
echo "=== CMVER"; /cm/local/apps/cmd/sbin/cmsh --version 2>&1 | head -20
echo "=== IPR"; ip r 2>&1
echo "=== HOSTS"; grep -vE '^#|localhost' /etc/hosts 2>/dev/null | head -80
echo "=== SSHDIR"; ls -l /root/.ssh 2>&1 | head -20; ls -l /cm/local/apps/cmd/etc/ssh 2>&1 | head -20
echo "=== PS"; ps -eo pid,user,args 2>/dev/null | grep -Ei 'cmdaemon|cmsh|cmd\.service|cmd -' | grep -v grep | head -20
echo "=== UNITS"; systemctl list-units --type=service --state=running 2>/dev/null | grep -iE 'cm|bright' | head -20
echo "=== DEVICELIST"; timeout 60 cmsh -c 'device list' 2>&1 | head -100
echo "=== DEVSTATUS"; timeout 60 cmsh -c 'device status' 2>&1 | head -80
echo "=== MODELLIST"; timeout 60 cmsh -c 'device; list' 2>&1 | head -60
echo "=== PARTITION"; timeout 40 cmsh -c 'partition list' 2>&1 | head -30
echo "=== CATEGORY"; timeout 40 cmsh -c 'category list' 2>&1 | head -30
echo "=== HTTPAPI"; ss -lntp 2>/dev/null | grep -E ':8080|:8081|:8443' | head
echo "=== DONE"
