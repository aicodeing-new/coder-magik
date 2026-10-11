import socket,struct,os,json,time
for host in ['223.5.5.5','114.114.114.114']:
 s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.settimeout(2)
 txn=os.urandom(2);name=b'\x05coder\x0amagikcloud\x02cn\x00'
 pkt=txn+struct.pack('!HHHHH',0x100,1,0,0,0)+name+struct.pack('!HH',1,1)
 try:
  s.sendto(pkt,(host,53));r,a=s.recvfrom(4096);print(json.dumps({'test':'public DNS UDP/53','server':host,'response':r[:2]==txn}),flush=True)
 except Exception as e:print(json.dumps({'test':'public DNS UDP/53','server':host,'error':str(e)}),flush=True)
 s.close()
try:
 receive=socket.socket(socket.AF_INET,socket.SOCK_RAW,socket.IPPROTO_ICMP);receive.settimeout(2)
 for ttl in [1,2,3]:
  s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.setsockopt(socket.SOL_IP,socket.IP_TTL,ttl)
  s.sendto(b'coder-p2p-diagnostic',('223.5.5.5',3478))
  try:
   r,a=receive.recvfrom(4096);offset=(r[0]&15)*4;print(json.dumps({'test':'UDP route trace','ttl':ttl,'hop':a[0],'icmp_type':r[offset],'icmp_code':r[offset+1]}),flush=True)
  except Exception as e:print(json.dumps({'test':'UDP route trace','ttl':ttl,'error':str(e)}),flush=True)
  s.close()
 receive.close()
except PermissionError as e:print('Trace unavailable:',e)
