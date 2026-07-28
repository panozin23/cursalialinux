#!/usr/bin/env python3
# Controla QEMU por QMP: captura pantalla, mueve/clic raton (usb-tablet abs), teclea.
import socket, json, sys, time

SOCK = sys.argv[1]
W, H = 1280, 800

def conn():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)
    f = s.makefile('rw')
    f.readline()
    f.write(json.dumps({"execute":"qmp_capabilities"})+'\n'); f.flush(); f.readline()
    return s, f

def ex(f, o):
    f.write(json.dumps(o)+'\n'); f.flush()
    return f.readline()

def ax(v, n): return max(0, min(32767, int(v/(n-1)*32767)))

def move(f, x, y):
    ex(f, {"execute":"input-send-event","arguments":{"events":[
        {"type":"abs","data":{"axis":"x","value":ax(x,W)}},
        {"type":"abs","data":{"axis":"y","value":ax(y,H)}}]}})

def click(f, x, y, dbl=False):
    move(f, x, y); time.sleep(0.3)
    for _ in range(2 if dbl else 1):
        ex(f, {"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":True,"button":"left"}}]}})
        ex(f, {"execute":"input-send-event","arguments":{"events":[{"type":"btn","data":{"down":False,"button":"left"}}]}})
        if dbl: time.sleep(0.12)

KEYMAP = {' ':'spc','-':'minus','.':'dot','_':'shift+minus','@':'shift+2'}
def sendkey(f, qcode):
    if '+' in qcode:
        parts = qcode.split('+')
        evs=[{"type":"key","data":{"down":True,"key":{"type":"qcode","data":p}}} for p in parts]
        evs+=[{"type":"key","data":{"down":False,"key":{"type":"qcode","data":p}}} for p in reversed(parts)]
        ex(f, {"execute":"input-send-event","arguments":{"events":evs}})
    else:
        ex(f, {"execute":"input-send-event","arguments":{"events":[
            {"type":"key","data":{"down":True,"key":{"type":"qcode","data":qcode}}},
            {"type":"key","data":{"down":False,"key":{"type":"qcode","data":qcode}}}]}})

def typetext(f, t):
    for ch in t:
        if ch.isalpha(): qc = ('shift+' if ch.isupper() else '')+ch.lower()
        elif ch.isdigit(): qc = ch
        elif ch in KEYMAP: qc = KEYMAP[ch]
        else: qc = 'spc'
        sendkey(f, qc); time.sleep(0.04)

s, f = conn()
cmd = sys.argv[2]
if cmd == 'shot':
    line = ex(f, {"execute":"screendump","arguments":{"filename":sys.argv[3],"format":"png"}})
    if '"error"' in line: ex(f, {"execute":"screendump","arguments":{"filename":sys.argv[3]}})
    print(line.strip())
elif cmd == 'click':   click(f, int(sys.argv[3]), int(sys.argv[4]))
elif cmd == 'dblclick':click(f, int(sys.argv[3]), int(sys.argv[4]), dbl=True)
elif cmd == 'type':    typetext(f, sys.argv[3])
elif cmd == 'key':     sendkey(f, sys.argv[3])
elif cmd == 'move':    move(f, int(sys.argv[3]), int(sys.argv[4]))
s.close()
