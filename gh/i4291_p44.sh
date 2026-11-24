#!/bin/bash
set +e
echo "###P44START $(date -u)"
F=/root/q/p43-1795555021.log
echo "===== $F size=$(stat -c %s "$F" 2>/dev/null)"
cat "$F" 2>&1 | head -c 14000
echo "###P44END $(date -u)"
