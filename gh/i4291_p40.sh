#!/bin/bash
set +e
echo "###P40START $(date -u)"
pgrep -fa '/root/q/' | head -4; ls -lt /root/q/*.log | head -5
for f in /root/q/p38-1795553930.log /root/q/p39-1795553947.log /root/q/p34-1795552882.log; do
  echo "===== $f size=$(stat -c %s "$f" 2>/dev/null)"
  head -c 4000 "$f" 2>&1; echo; echo "--TAIL--"; tail -c 3000 "$f" 2>&1
done
echo "###P40END $(date -u)"
