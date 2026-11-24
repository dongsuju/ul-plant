#!/bin/bash
set +e
echo "###P37START $(date -u)"
pgrep -fa '/root/q/' | head -4; ls -lt /root/q/ | head -6
F=/root/q/p36-1795553210.log
echo "===== $F size=$(stat -c %s "$F" 2>/dev/null)"
cat "$F" 2>&1 | head -c 8000
echo "###P37END $(date -u)"
