from pathlib import Path
import json,hashlib
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/farming-validation-planning-2026-09-20';p=e/'frozen-witnesses.json';j=json.loads(p.read_text());j['physical_coverage']='Every4096physicalrow with faultfield=row%15, plus each15field athead/tail and163domain/stateimages; not a full15x4096Cartesian fault campaign';p.write_text(json.dumps(j,indent=2)+'\n')
def rule(case):
 c=[[(-1 if f in [1,8,12,13] else 0)]*4096 for f in range(15)]
 for key,val in j['fixtures'][case['base']].items():c[j['fields'].index(key)][4095]=val
 for f,row,val in case['changes']:c[f][row]=val
 if any(x not in [0,1] for x in c[0]):return 'COLUMN_PRESENT'
 for row in range(4096):
  present,crop,state,soil,fert,moist,growth,health,family,streak,compost,day,tile,slot,gen=[col[row] for col in c]
  if not(-1<=crop<5 and 0<=state<5 and 0<=soil<3):return 'COLUMN_ENUM'
  if not(0<=fert<=10000 and 0<=moist<=10000 and 0<=health<=10000 and growth>=0 and compost in [0,2000] and day>=0):return 'COLUMN_VALUE'
  if not(-1<=family<5 and streak>=0 and((family==-1 and streak==0) or(family>=0 and streak>=1))):return 'COLUMN_HISTORY'
  if present:
   if not(0<=tile<16384 and 0<=slot<352418 and gen>0):return 'COLUMN_IDENTITY'
  elif (tile,slot,gen)!=(-1,-1,0):return 'COLUMN_IDENTITY'
  if not present:
   if crop!=-1 or state!=0:return 'COLUMN_FREE_ROW'
  elif state==0:
   if crop!=-1 or growth!=0 or health!=10000 or day!=0:return 'COLUMN_STATE'
  else:
   if crop<0 or day<1 or ([3,3,5,3,5][crop]&(1<<soil))==0:return 'COLUMN_STATE'
   target=[144,120,168,192,120][crop]*1000
   if growth>target+999:return 'COLUMN_STATE'
   if state==1 and(growth!=0 or health!=10000):return 'COLUMN_STATE'
   if state==2 and(health<=0 or growth>=target):return 'COLUMN_STATE'
   if state==3 and(health<=0 or growth<target):return 'COLUMN_STATE'
   if state==4 and((health==0 and growth>=target) or(health>0 and growth<target)):return 'COLUMN_STATE'
 for f,code in [(12,'COLUMN_DUPLICATE_TILE'),(13,'COLUMN_DUPLICATE_REF')]:
  vals=[v for v in c[f] if v>=0]
  if len(set(vals))!=len(vals):return code
 return ''
bad=[dict(case=c['name'],expected=c['code'],actual=rule(c)) for c in j['cases'] if rule(c)!=c['code']];print(json.dumps(bad,indent=2));assert not bad
(e/'fixture-arithmetic-check.json').write_text(json.dumps(dict(kind='Python contract consistency model only; not Godot or implementation evidence',cases=len(j['cases']),failures=0,witness_sha256=hashlib.sha256(p.read_bytes()).hexdigest()),indent=2)+'\n')
