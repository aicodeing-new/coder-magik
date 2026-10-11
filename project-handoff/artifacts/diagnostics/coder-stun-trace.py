import socket,os,struct,json
receive=socket.socket(socket.AF_INET,socket.SOCK_RAW,socket.IPPROTO_ICMP);receive.settimeout(1)
target=socket.gethostbyname('stun.cloudflare.com')
for ttl in range(4,10):
 s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.setsockopt(socket.SOL_IP,socket.IP_TTL,ttl)
 s.sendto(struct.pack('!HHI',1,0,0x2112a442)+os.urandom(12),(target,3478))
 try:
  r,a=receive.recvfrom(4096);offset=(r[0]&15)*4
  print(json.dumps({'ttl':ttl,'hop':a[0],'icmp_type':r[offset],'icmp_code':r[offset+1]}),flush=True)
 except socket.timeout:print(json.dumps({'ttl':ttl,'hop':'no ICMP response'}),flush=True)
 s.close()
receive.close()
