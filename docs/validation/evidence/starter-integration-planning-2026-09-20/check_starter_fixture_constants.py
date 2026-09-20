"""Read-only compare candidate immutable layout literals with frozen GDD arithmetic."""
from pathlib import Path
import ast,hashlib,json,re,sys
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/starter-integration-planning-2026-09-20';s=(e/'candidate-starter_structures.gd').read_text();ref=json.loads((e/'layout-reference.json').read_text());keys=dict(re.findall(r'^const ([A-Z_]+_KEY): String = "([^"]+)"$',s,re.M))
def array(name):
 m=re.search(r'^const '+name+r': Array(?:\[[^\]]+\])? = ',s,re.M);assert m,name
 start=m.end();depth=0;quote=None;end=None
 for i,ch in enumerate(s[start:],start):
  if quote:
   if ch==quote and s[i-1]!='\\':quote=None
   continue
  if ch in '\"\'':quote=ch
  elif ch=='[':depth+=1
  elif ch==']':
   depth-=1
   if depth==0:end=i+1;break
 assert end
 text=s[start:end];text=re.sub(r'\b([A-Z_]+_KEY)\b',lambda m:repr(keys[m[0]]),text)
 return ast.literal_eval(text)
symbol={'B':'bed','T':'seat','S':'shelf','K':'kitchen_bench','H':'hearth'}
expected=[[symbol[x['symbol']],x['origin'],x['room'],x['footprint'],x['candidate_walk_tiles']] for x in ref['floor_furniture']]
assert array('FURNITURE_ENTRIES')==expected
assert array('BUILD_ORIGIN_X')==[58,50,50,70,70,64,58]
assert array('BUILD_ORIGIN_Z')==[59,60,65,60,65,54,54]
assert array('ROOM_TILE_COUNTS')==[40,10,25,5]
assert array('ROOM_TILE_OFFSETS')==[0,40,50,75]
assert array('ROOM_LOCAL_BOUNDS')==[[0,4,0,7],[5,9,0,1],[5,9,2,6],[5,9,7,7]]
assert array('EDGE_ENTRIES')==[[z*10+4,z*10+5,'interior_door' if z==4 else 'interior_partition',0,1 if z<2 else 2 if z<7 else 3] for z in range(8)]
record={'scope':'Immutable source fixture comparison, not runtime validation or physical admission','candidate_sha256':hashlib.sha256(s.encode()).hexdigest(),'reference_sha256':hashlib.sha256((e/'layout-reference.json').read_bytes()).hexdigest(),'checks':7,'result':'pass'}
if len(sys.argv)>1:
 p=e/sys.argv[1];assert not p.exists();p.write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
