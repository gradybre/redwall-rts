import ast,re,json,copy,hashlib
from pathlib import Path
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');p=r/'godot/scripts/core/save_component_columns_schema.gd';s=p.read_text();base={m[1]:ast.literal_eval(m[2]) for m in re.finditer(r'const (\w+): Array = (\[.*?\])',s,re.S)};width={0:1,2:4,4:8}
def validate(t):
 fields=children=rows=0;offset=4
 for i in range(18):
  assert (t['OWNER_FIELD_BEGIN'][i],t['OWNER_CHILD_BEGIN'][i],t['OWNER_OFFSETS'][i])==(fields,children,offset)
  assert len(t['OWNER_KEYS'][i].encode())==t['OWNER_KEY_BYTES'][i]
  assert i==0 or t['OWNER_KEYS'][i-1]<t['OWNER_KEYS'][i]
  n=t['OWNER_FIELD_COUNTS'][i];ch=t['OWNER_CHILD_COUNTS'][i];assert n>0 and ch>=0 and t['OWNER_PRIMARY_COUNTS'][i]>0
  assert all(x>0 for x in t['CHILD_EXTENTS'][children:children+ch])
  count=4+8*ch+sum(8+t['FIELD_COUNTS'][f]*width[t['FIELD_TYPES'][f]] for f in range(fields,fields+n))
  assert t['OWNER_PAYLOAD_BYTES'][i]==count and t['OWNER_BLOCK_BYTES'][i]==count+24+t['OWNER_KEY_BYTES'][i]
  fields+=n;children+=ch;rows+=t['OWNER_PRIMARY_COUNTS'][i];offset+=t['OWNER_BLOCK_BYTES'][i]
 assert (fields,children,rows)==(298,5,193184)
 return offset
out=[]
for fault in ['control','key','version','primary','children','field_count','field_key','field_type','field_extent']:
 t=copy.deepcopy(base)
 if fault=='key':t['OWNER_KEYS'][4]='fishinh'
 if fault=='version':t['OWNER_VERSIONS'][4]=2
 if fault=='primary':t['OWNER_PRIMARY_COUNTS'][4]+=1;t['OWNER_PRIMARY_COUNTS'][5]-=1
 if fault=='children':t['OWNER_CHILD_COUNTS'][4]=1;t['OWNER_CHILD_COUNTS'][7]=0;t['OWNER_CHILD_BEGIN'][5]+=1;t['OWNER_CHILD_BEGIN'][6]+=1;t['OWNER_CHILD_BEGIN'][7]+=1
 if fault=='field_count':t['OWNER_FIELD_COUNTS'][4]+=1;t['OWNER_FIELD_COUNTS'][5]-=1;t['OWNER_FIELD_BEGIN'][5]+=1
 if fault=='field_key':t['FIELD_KEYS'][80]='_changed'
 if fault=='field_type':t['FIELD_TYPES'][80]=2
 if fault=='field_extent':t['FIELD_COUNTS'][80]+=1
 offset=4
 for i in range(18):
  a=t['OWNER_FIELD_BEGIN'][i];n=t['OWNER_FIELD_COUNTS'][i];payload=4+8*t['OWNER_CHILD_COUNTS'][i]+sum(8+t['FIELD_COUNTS'][f]*width[t['FIELD_TYPES'][f]] for f in range(a,a+n))
  t['OWNER_PAYLOAD_BYTES'][i]=payload;t['OWNER_BLOCK_BYTES'][i]=payload+24+t['OWNER_KEY_BYTES'][i];t['OWNER_OFFSETS'][i]=offset;offset+=t['OWNER_BLOCK_BYTES'][i]
 assert validate(t)==offset
 out.append(dict(case=fault,changes={name:{str(i):v for i,v in enumerate(values) if v!=base[name][i]} for name,values in t.items() if values!=base[name]},section_bytes=offset,expected_section_bytes=offset,descriptor_rows=193184,fields=298,children=5,expected_schema_refusal='',expected_bridge_refusal='' if fault=='control' else 'SAVE_COMPONENT_METADATA'))
e=r/'docs/validation/evidence/fishing-validation-planning-2026-09-20';(e/'metadata-arithmetic-check.json').write_text(json.dumps(dict(kind='Python arithmetic only; not Godot execution',schema_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),cases=out),indent=2)+'\n')
print('9 internally coherent schema images, including control;8faults plus8bypasses/control/schema-forward=18engine cases;9source-table cases additionally planned')
