#!/usr/bin/env python3
import socket, json, sys, time

sock_path, out = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock_path)
f = s.makefile('rw')
def cmd(o):
    f.write(json.dumps(o)+'\n'); f.flush()
    return f.readline()
f.readline()                       # greeting
cmd({"execute":"qmp_capabilities"})
# intenta PNG; si falla, PPM
line = cmd({"execute":"screendump","arguments":{"filename":out,"format":"png"}})
if '"error"' in line:
    line = cmd({"execute":"screendump","arguments":{"filename":out}})
print(line.strip())
s.close()
