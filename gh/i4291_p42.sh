#!/bin/bash
set +e
echo "###P42START $(date -u)"
ls -lt /root/q/*.log | head -4
F=/root/q/p41-1795554520.log
echo "===== $F size=$(stat -c %s "$F" 2>/dev/null)"
cat "$F" 2>&1 | head -c 12000
echo "###P42END $(date -u)"
