#!/bin/bash
set +e
echo "###P36START $(date -u)"
mkdir -p /root/q; pgrep -f '/root/q/run.sh' >/dev/null || (setsid nohup bash /root/q/run.sh >/root/q/daemon.log 2>&1 &)
cat > /root/q/p36-1795553210.todo <<'BODYEOF'
#!/bin/bash
set +e
echo "###P36START $(date -u)"
run() {
  hp=$1; user=$2; tag=$3
  echo "===== CONSOLE $hp user=$user"
  timeout 20 vncdo -s $hp capture /root/q/c_${tag}_pre.png 2>&1 | tail -1
  timeout 40 vncdo -s $hp key enter pause 2 type "$user" key enter pause 3 capture /root/q/c_${tag}_u.png 2>&1 | tail -1
  echo "--- after-user OCR:"; timeout 30 tesseract /root/q/c_${tag}_u.png - 2>/dev/null | tr -s '\n' '|' | head -c 300; echo
  timeout 40 vncdo -s $hp type '/&S2)n@W1G' key enter pause 5 capture /root/q/c_${tag}_p.png 2>&1 | tail -1
  echo "--- after-pw OCR:"; timeout 30 tesseract /root/q/c_${tag}_p.png - 2>/dev/null | tr -s '\n' '|' | head -c 500; echo
  timeout 40 vncdo -s $hp type 'id; hostname; nvidia-smi -L; ls /dev/nvidia* 2>/dev/null | wc -l; ip -4 a | grep inet | head -3' key enter pause 6 capture /root/q/c_${tag}_cmd.png 2>&1 | tail -1
  echo "--- after-cmd OCR:"; timeout 30 tesseract /root/q/c_${tag}_cmd.png - 2>/dev/null | tr -s '\n' '|' | head -c 800; echo
}
run 192.168.2.45::5900 root h45
run 192.168.2.63::5900 root h63
run 192.168.2.41::5900 root h41
run 192.168.2.36::5901 root h36
ls -l /root/q/c_*.png 2>&1 | tail -6
echo "###P36END $(date -u)"
BODYEOF
ls -l /root/q/ | tail -2
echo "###P36END $(date -u)"
