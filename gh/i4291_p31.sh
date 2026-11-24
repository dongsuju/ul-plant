#!/bin/bash
set +e
echo "###P31START $(date -u)"
pgrep -fa '/root/q/' | head -6
ls -lt /root/q/ | head -8
L=$(ls -t /root/q/p30-*.log 2>/dev/null | head -1)
echo "LOG=$L size=$(stat -c %s "$L" 2>/dev/null)"
echo "=== HEAD ==="; head -c 2000 "$L" 2>&1
echo; echo "=== TAIL ==="; tail -c 12000 "$L" 2>&1
echo "###P31END $(date -u)"
