#!/bin/bash
set +e
echo "###P10START $(date -u)"
echo "=== VNC-CONSOLE-SNAPSHOT ==="
cat > /tmp/rfb.py <<'PY'
import socket,struct,sys,time
def rd(s,n):
    b=b""
    while len(b)<n:
        d=s.recv(n-len(b))
        if not d: raise EOFError
        b+=d
    return b
def snap(host,port,fn):
    s=socket.create_connection((host,port),timeout=6); s.settimeout(15)
    ver=rd(s,12); s.sendall(b"RFB 003.008\n")
    n=rd(s,1)[0]; types=rd(s,n)
    if 1 not in types: print(host,port,"no None auth, types",list(types)); return
    s.sendall(b"\x01")
    r=rd(s,4); 
    if r!=b"\x00\x00\x00\x00": print(host,port,"secresult",r); return
    s.sendall(b"\x01")
    w,h=struct.unpack(">HH",rd(s,4)); pfs=rd(s,16); nl=struct.unpack(">I",rd(s,4))[0]; name=rd(s,nl)
    print(host,port,"ServerInit %dx%d name=%r"%(w,h,name))
    # SetPixelFormat: bpp32 depth24 bigendian0 truecolour1 rmax255 gmax255 bmax255 rshift16 gshift8 bshift0
    s.sendall(bytes([0,0,0,0,32,24,0,1])+struct.pack(">HHH",255,255,255)+bytes([16,8,0,0,0,0,0]))
    s.sendall(struct.pack(">BBH",2,0,1)+struct.pack(">i",0))
    s.sendall(struct.pack(">BBHHHH",3,0,0,0,w,h))
    try:
        mtype=rd(s,1)[0]
        if mtype!=0:
            print("first msg",mtype); return
        rd(s,1); nrects=struct.unpack(">H",rd(s,2))[0]
        buf=bytearray(b"\x00"*(w*h*3))
        for i in range(nrects):
            x,y,rw,rh=struct.unpack(">HHHH",rd(s,8)); enc=struct.unpack(">i",rd(s,4))[0]
            if enc!=0: print("enc",enc,"skip"); continue
            px=rd(s,rw*rh*4)
            for yy in range(rh):
                for xx in range(rw):
                    o=(yy*rw+xx)*4; b_,g_,r_=px[o],px[o+1],px[o+2]
                    t=((y+yy)*w+(x+xx))*3
                    buf[t:t+3]=bytes([r_,g_,b_])
        open(fn,"wb").write(b"P6\n%d %d\n255\n"%(w,h)+bytes(buf))
        print("saved",fn,w,h,"rects",nrects)
    except Exception as e: print("fb err",type(e).__name__)
    s.close()
for h,p,n in [("192.168.2.36",5901,"vnc_36"),("192.168.2.41",5900,"vnc_41"),("192.168.2.45",5900,"vnc_45"),("192.168.2.63",5900,"vnc_63")]:
    try: snap(h,p,"/tmp/%s.ppm"%n)
    except Exception as e: print(h,p,"ERR",type(e).__name__,str(e)[:60])
PY
python3 /tmp/rfb.py 2>&1 | head -40
echo "=== SNAP-DIMS ==="; for f in /tmp/vnc_*.ppm; do [ -f "$f" ] && echo "$f $(head -c 30 $f | tr '\n' ' ') size=$(stat -c%s $f)"; done
echo "=== 9100-UI ==="; curl -s -x http://172.17.0.1:1080 -m 6 http://127.0.0.1:9100/ | sed -e 's/<[^>]*>/ /g' | tr -s ' \n' ' ' | head -c 700; echo
echo "=== 9100-PPROF-CMDLINE ==="; curl -s -x http://172.17.0.1:1080 -m 6 "http://127.0.0.1:9100/debug/pprof/cmdline" | tr '\0' ' '; echo
echo "=== 9100-PPROF-GOROUTINE ==="; curl -s -x http://172.17.0.1:1080 -m 8 "http://127.0.0.1:9100/debug/pprof/goroutine?debug=1" | head -c 800; echo
echo "=== 9100-PPROF-HEAP-SAMPLE ==="; curl -s -x http://172.17.0.1:1080 -m 10 "http://127.0.0.1:9100/debug/pprof/heap?debug=1" | head -c 1200; echo
echo "=== SVC-METRICS-NAMES ==="
for port in 2023 2025 6063 8081 10221 8429 123; do echo "--- $port"; curl -s -x http://172.17.0.1:1080 -m 6 "http://127.0.0.1:$port/metrics" 2>/dev/null | grep -E "^# (HELP|TYPE)" | head -6; done
echo "=== 2023-ROOT ==="; curl -s -x http://172.17.0.1:1080 -m 6 http://127.0.0.1:2023/ | head -c 200; echo; curl -s -x http://172.17.0.1:1080 -m 6 -D - -o /dev/null http://127.0.0.1:2023/ | head -10
echo "=== 2025-PATHS ==="; for u in / /healthz /metrics /api/v1/files /files /list /v1 /ping; do printf "%s " "$u"; curl -s -x http://172.17.0.1:1080 -m 5 -o /tmp/q.$$ -w "c=%{http_code} l=%{size_download} " "http://127.0.0.1:2025$u"; head -c 100 /tmp/q.$$ | tr '\n' ' '; echo; done
echo "=== 10221-PATHS ==="; for u in / /healthz /metrics /api/v1 /v1 /debug/pprof/cmdline; do printf "%s " "$u"; curl -s -x http://172.17.0.1:1080 -m 5 -o /tmp/q2.$$ -w "c=%{http_code} l=%{size_download} " "http://127.0.0.1:10221$u"; head -c 100 /tmp/q2.$$ | tr '\n' ' '; echo; done
echo "=== SIB-8080-PATHS ==="
for h in 172.17.0.3 172.17.0.4 172.17.0.7; do for u in / /healthz /api /api/status /files /download /static/ /metrics /ping /version; do printf "%s%s " "$h" "$u"; curl -s -m 4 -o /tmp/s.$$ -w "c=%{http_code} l=%{size_download} " "http://$h:8080$u"; head -c 80 /tmp/s.$$ | tr '\n' ' '; echo; done; done
echo "###P10END $(date -u)"
