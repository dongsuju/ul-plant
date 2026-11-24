#!/bin/bash
set +e
echo "###P29START $(date -u)"
pgrep -fa '/root/q/' | head -5
ls -lt /root/q/ | head -10
L=$(ls -t /root/q/p28-*.log 2>/dev/null | head -1)
echo "LOG=$L size=$(stat -c %s "$L" 2>/dev/null)"
echo "=== HEAD ==="; head -c 2500 "$L" 2>&1
echo; echo "=== TAIL ==="; tail -c 9000 "$L" 2>&1
echo "###P29END $(date -u)"
