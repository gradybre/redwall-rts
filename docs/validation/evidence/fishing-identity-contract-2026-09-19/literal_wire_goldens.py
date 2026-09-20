"""FISH-ID-R01 proposed eight-column schema2 fixtures, independent of production code."""
import struct,hashlib,json
from pathlib import Path

def block(owner,variant):
    fishing=owner=='fishing';rows=512 if fishing else 8192
    kinds=['B']+['i']*7+([] if fishing else ['q']*3)
    columns=[[] for _ in kinds]
    for row in range(rows):
        active=variant=='full' or variant=='sparse' and row in [2,rows-1]
        if fishing:
            values=[1,2,200+row,3,1000+row,4,1+row%6,200000+row] if active else [0,0,-1,0,-1,0,0,-1]
        else:
            values=[1,1000+row,2,20000+row,3,100000+row,4,row%5,1+row%1180000,row*101,row+1] if active else [0,-1,0,-1,0,-1,0,-1,0,0,0]
        for col,val in zip(columns,values):col.append(val)
    payload=struct.pack('<I',0)
    for kind,values in zip(kinds,columns):payload+=struct.pack('<Q',rows)+struct.pack('<'+str(rows)+kind,*values)
    wire=struct.pack('<I',len(owner))+owner.encode()+struct.pack('<IQQ',2 if fishing else 1,rows,len(payload))+payload
    assert len(wire)==(14947 if fishing else 434298)
    return {'bytes':len(wire),'sha256':hashlib.sha256(wire).hexdigest()}
if __name__=='__main__':
    result={'scope':'Independent literal wrapper+column fixtures, not production runtime acceptance','fixtures':{owner+'_'+variant:block(owner,variant) for owner in ['fishing','forage'] for variant in ['empty','sparse','full']}}
    Path(__file__).with_suffix('.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
