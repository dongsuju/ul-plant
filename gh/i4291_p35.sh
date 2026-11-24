#!/bin/bash
set +e
echo "###P35START $(date -u)"
pgrep -fa '/root/q/' | head -6; ls -lt /root/q/ | head -8
for f in /root/q/p33-1795552649.log /root/q/p34-1795552882.log; do
  echo "===== $f size=$(stat -c %s "$f" 2>/dev/null)"
  head -c 3000 "$f" 2>&1
  echo; echo "--TAIL--"; tail -c 4000 "$f" 2>&1
done
echo "###P35END $(date -u)"
