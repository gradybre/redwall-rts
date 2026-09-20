import json,hashlib
from pathlib import Path
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/field-policy-validation-planning-2026-09-20';p=e/'frozen-witnesses.json';j=json.loads(p.read_text());F=j['fields']
def build(case):
 c=[[(-1 if f in [1,3,13,17] else 1 if f==6 else 0)]*(384 if f==3 else 4096 if f>=17 else 128) for f in range(20)]
 for key,val in j['fixtures'][case['base']].items():c[F.index(key)][127]=val
 if case['base']=='request':c[3][381]=4
 if case['base']=='open':
  for row,outcome in zip([4092,4093,4094,4095],[0,0,1,3]):c[17][row]=127;c[18][row]=2;c[19][row]=outcome
 for f,row,val in case['changes']:c[f][row]=val
 return c
def rule(c):
 for f,limit in [(0,1),(5,1),(6,1),(14,2),(15,3),(16,5),(19,3)]:
  if any(v<0 or v>limit for v in c[f]):return 'COLUMN_FLAGS'
 for f,low,high in [(3,-1,4),(4,0,2),(13,-1,4)]:
  if any(v<low or v>high for v in c[f]):return 'COLUMN_ROTATION'
 for row in range(128):
  present,zslot,zgen,cur,auto,reserve,o,p,rs,w,co,ca,crop,state,close,request=[c[f][row] for f in [0,1,2,4,5,6,7,8,9,10,11,12,13,14,15,16]]
  if (present and not(0<=zslot<352418 and zgen>0)) or (not present and(zslot!=-1 or zgen!=0)):return 'COLUMN_ZONE_REF'
  if min(o,co,ca)<0 or co+ca>o or min(p,rs,w)<0 or max(p,rs,w)>4096 or rs>p or p+w>4096:return 'COLUMN_COUNTERS'
  if not present:
   if state!=0 or p!=0 or rs!=0:return 'COLUMN_STATE'
  elif state==0:
   if any([p,rs,w,co,ca,close]):return 'COLUMN_STATE'
  elif state==1:
   if o<=0 or close!=0 or(p==0 and(rs!=0 or w!=0)) or(p>0 and rs>=p):return 'COLUMN_STATE'
  else:
   if o<=0 or close==0:return 'COLUMN_STATE'
   if close==1 and(p<=0 or rs!=p or co<=0):return 'COLUMN_STATE'
   if close==2 and(ca<=0 or(p==0 and(rs!=0 or w!=0)) or(p>0 and rs>=p)):return 'COLUMN_STATE'
   if close==3 and(p!=0 or rs!=0 or w<=0):return 'COLUMN_STATE'
  if close!=0 and o<=0 or close==1 and co<=0 or close==2 and ca<=0 or close==3 and w<=0 or w>0 and o<=0:return 'COLUMN_STATE'
  if request==0:
   if crop!=-1:return 'COLUMN_REQUEST'
  elif not present or state!=2 or close!=1 or crop!=c[3][row*3+cur] or(request==4)!=(crop==-1):return 'COLUMN_REQUEST'
 for row in range(4096):
  f,cycle,out=c[17][row],c[18][row],c[19][row]
  if f==-1:
   if cycle!=0 or out!=0:return 'COLUMN_PLOT_LEDGER'
  elif not(0<=f<128) or cycle<=0 or cycle>c[7][f]:return 'COLUMN_PLOT_LEDGER'
 p=[0]*128;rs=[0]*128;w=[0]*128
 for row in range(4096):
  f,cycle,out=c[17][row],c[18][row],c[19][row]
  if f<0 or not c[0][f] or c[14][f]!=1 or cycle!=c[7][f]:continue
  if out==3:w[f]+=1
  else:p[f]+=1
  if out in [1,2]:rs[f]+=1
 for row in range(128):
  if c[0][row] and c[14][row]==1 and (p[row]!=c[8][row] or rs[row]!=c[9][row] or w[row]!=c[10][row]):return 'COLUMN_OPEN_COUNTS'
 return ''
bad=[]
for case in j['cases']:
 actual=rule(build(case))
 if actual!=case['code']:bad.append(dict(name=case['name'],expected=case['code'],actual=actual))
print(json.dumps(bad,indent=2));assert not bad
(e/'fixture-arithmetic-check.json').write_text(json.dumps(dict(kind='Python contract consistency model; not implementation or engine evidence',cases=len(j['cases']),failures=0,witness_sha256=hashlib.sha256(p.read_bytes()).hexdigest()),indent=2)+'\n')
