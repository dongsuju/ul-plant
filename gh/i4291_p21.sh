#!/bin/bash
set +e
echo "###P21START $(date -u)"
pgrep -fa '/root/q/(p2[0-9]|run)' | head -4
ls -l /root/q/
echo "=== LOG-HEAD ==="; head -c 1200 /root/q/p20.log 2>&1
echo; echo "=== LOG-TAIL ==="; tail -c 6000 /root/q/p20.log 2>&1
echo "###P21END $(date -u)"
