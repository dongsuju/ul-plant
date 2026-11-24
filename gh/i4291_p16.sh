#!/bin/bash
set +e
echo "###P16START $(date -u)"
echo "=== HOSTLOOP-DOCKER-STYLE ==="
for port in 2023 2025 8429 10221 123 8081 9100; do
  for u in /_ping /version /info /containers/json /images/json /v1.41/version /v1.41/containers/json /events /swarm; do
    r=$(curl -s -x http://172.17.0.1:1080 -m 4 -o /tmp/d.$$ -w "%{http_code}" "http://127.0.0.1:$port$u" 2>/dev/null)
    b=$(head -c 80 /tmp/d.$$ | tr '\n' ' ')
    case "$r" in 000|404) ;; *) echo "$port$u c=$r b=$b";; esac
  done
done
echo "=== 123-HOST-ROUTING ==="
for host in instance proxy-ai.onethingai.com localhost 127.0.0.1 admin api.onethingai.com cpwx707f53e94e69; do echo "--- Host: $host"; curl -s -x http://172.17.0.1:1080 -m 4 -H "Host: $host" -D - -o /tmp/h.$$ "http://127.0.0.1:123/" 2>/dev/null | head -5; head -c 80 /tmp/h.$$; echo; done
echo "=== 2023/2025/8429/10221 HEADERS+ROOT ==="
for port in 2023 2025 8429 10221; do echo "--- $port"; curl -s -x http://172.17.0.1:1080 -m 4 -D - -o /tmp/r.$$ "http://127.0.0.1:$port/" 2>/dev/null | head -8; head -c 120 /tmp/r.$$; echo; done
echo "=== 9100-UI-TEXT ==="; curl -s -x http://172.17.0.1:1080 -m 5 http://127.0.0.1:9100/ | sed -e 's/<[^>]*>/ /g' | tr -s ' \n' ' ' | head -c 500; echo
echo "=== 9100-OTHER ==="; for u in /api /api/v1/instances /instances /debug/pprof/ /config /flags; do printf "%s " "$u"; curl -s -x http://172.17.0.1:1080 -m 4 -o /tmp/k.$$ -w "c=%{http_code} l=%{size_download} " "http://127.0.0.1:9100$u"; head -c 80 /tmp/k.$$ | tr '\n' ' '; echo; done
echo "###P16END $(date -u)"
