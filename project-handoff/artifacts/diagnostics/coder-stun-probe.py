import socket,struct,os,json,time
servers=[('stun.l.google.com',19302),('stun1.l.google.com',19302),('stun2.l.google.com',19302),('stun.cloudflare.com',3478),('stun.miwifi.com',3478)]
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.bind(('0.0.0.0',0));s.settimeout(2)
print(json.dumps({'local_port':s.getsockname()[1]}),flush=True)
for host,port in servers:
 try:
  addr=socket.gethostbyname(host);transaction=os.urandom(12);packet=struct.pack('!HHI',1,0,0x2112a442)+transaction
  start=time.monotonic();s.sendto(packet,(addr,port));data,source=s.recvfrom(4096)
  assert data[8:20]==transaction
  mapped=[];offset=20
  while offset+4<=len(data):
   kind,length=struct.unpack('!HH',data[offset:offset+4]);value=data[offset+4:offset+4+length]
   if kind in [1,0x20] and len(value)>=8 and value[1]==1:
    p=struct.unpack('!H',value[2:4])[0];ip=struct.unpack('!I',value[4:8])[0]
    if kind==0x20:p^=0x2112;ip^=0x2112a442
    mapped.append(socket.inet_ntoa(struct.pack('!I',ip))+':'+str(p))
   offset+=4+((length+3)//4)*4
  print(json.dumps({'server':host+':'+str(port),'resolved_ip':addr,'mapped':mapped,'latency_ms':round((time.monotonic()-start)*1000,1)}),flush=True)
 except Exception as e: print(json.dumps({'server':host+':'+str(port),'error':str(e)}),flush=True)
s.close()
