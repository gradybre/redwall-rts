"""Independent literal section7 Gear block fixtures, not a production encoder."""
import struct,hashlib,json
from pathlib import Path

def block(rows,active):
    # owner2 has2u8 and10i32, declared ordinal order pinned independently.
    columns=[('B',[]),('i',[]),('i',[]),('i',[]),('i',[]),('i',[]),('i',[]),('i',[]),('i',[]),('B',[]),('i',[]),('i',[])]
    for row in range(rows):
        values=[1,row,3,0,row%1001,1000,-1,0,0,0,-1,0] if row in active else [0,-1,0,-1,0,0,-1,0,0,0,-1,0]
        for (_,column),value in zip(columns,values):column.append(value)
    payload=struct.pack('<I',0)
    for (kind,values) in columns:payload+=struct.pack('<Q',rows)+struct.pack('<'+str(rows)+kind,*values)
    assert len(payload)==100+42*rows
    wire=struct.pack('<I',4)+b'gear'+struct.pack('<IQQ',1,rows,len(payload))+payload
    assert len(wire)==128+42*rows
    return {'rows':rows,'active':len(active),'bytes':len(wire),'sha256':hashlib.sha256(wire).hexdigest()}
if __name__=='__main__':
    result={'scope':'Literal wrapper and column fixtures; not production encoder/runtime acceptance','fixtures':{'empty8':block(8,set()),'sparse8':block(8,{2,5}),'empty16384':block(16384,set()),'full16384':block(16384,set(range(16384)))}}
    Path(__file__).with_suffix('.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
