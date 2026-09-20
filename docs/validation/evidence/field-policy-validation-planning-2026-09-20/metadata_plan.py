import ast,re,json,copy,hashlib
from pathlib import Path
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');p=r/'godot/scripts/core/save_component_columns_schema.gd';s=p.read_text();base={m[1]:ast.literal_eval(m[2]) for m in re.finditer(r'const (\w+): Array = (\[.*?\])',s,re.S)}
width={0:1,2:4,4:8}
def validate(t):
 offset=4;fields=children=rows=0
 for i in range(18):
  assert t['OWNER_FIELD_BEGIN'][i]==fields and t['OWNER_CHILD_BEGIN'][i]==children and t['OWNER_OFFSETS'][i]==offset
  assert len(t['OWNER_KEYS'][i].encode())==t['OWNER_KEY_BYTES'][i]
  assert i==0 or t['OWNER_KEYS'][i-1]<t['OWNER_KEYS'][i]
  count=t['OWNER_FIELD_COUNTS'][i];child=t['OWNER_CHILD_COUNTS'][i]
  assert count>0 and child>=0 and t['OWNER_PRIMARY_COUNTS'][i]>0
  assert all(x>0 for x in t['CHILD_EXTENTS'][children:children+child])
  n=4+child*8+sum(8+t['FIELD_COUNTS'][k]*width[t['FIELD_TYPES'][k]] for k in range(fields,fields+count))
  assert n==t['OWNER_PAYLOAD_BYTES'][i]
  assert n+24+t['OWNER_KEY_BYTES'][i]==t['OWNER_BLOCK_BYTES'][i]
  offset+=t['OWNER_BLOCK_BYTES'][i];fields+=count;children+=child;rows+=t['OWNER_PRIMARY_COUNTS'][i]
 assert (fields,children,rows)==(298,5,193184)
 return offset
assert validate(base)==12947565
out=[]
for fault in ['control','key','version','primary','children','child_extent','field_count','field_key','field_type','field_extent']:
 t=copy.deepcopy(base)
 if fault=='key':t['OWNER_KEYS'][3]='field_policz'
 if fault=='version':t['OWNER_VERSIONS'][3]=2
 if fault=='primary':t['OWNER_PRIMARY_COUNTS'][3]+=1;t['OWNER_PRIMARY_COUNTS'][4]-=1
 if fault=='children':
  t['OWNER_CHILD_COUNTS'][3]=2;t['OWNER_CHILD_COUNTS'][7]=0
  for i in range(4,8):t['OWNER_CHILD_BEGIN'][i]+=1
 if fault=='child_extent':t['CHILD_EXTENTS'][2]=4097
 if fault=='field_count':t['OWNER_FIELD_COUNTS'][3]+=1;t['OWNER_FIELD_COUNTS'][4]-=1;t['OWNER_FIELD_BEGIN'][4]+=1
 if fault=='field_key':t['FIELD_KEYS'][60]='_changed'
 if fault=='field_type':t['FIELD_TYPES'][60]=2
 if fault=='field_extent':t['FIELD_COUNTS'][60]+=1
 # Rebuild only redundant arithmetic; never alter canonical field/child totals.
 offset=4
 for i in range(18):
  begin=t['OWNER_FIELD_BEGIN'][i];count=t['OWNER_FIELD_COUNTS'][i]
  n=4+8*t['OWNER_CHILD_COUNTS'][i]+sum(8+t['FIELD_COUNTS'][k]*width[t['FIELD_TYPES'][k]] for k in range(begin,begin+count))
  t['OWNER_PAYLOAD_BYTES'][i]=n;t['OWNER_BLOCK_BYTES'][i]=n+24+t['OWNER_KEY_BYTES'][i];t['OWNER_OFFSETS'][i]=offset;offset+=t['OWNER_BLOCK_BYTES'][i]
 assert validate(t)==offset
 changes={name:{str(i):v for i,v in enumerate(values) if v!=base[name][i]} for name,values in t.items() if values!=base[name]}
 out.append(dict(case=fault,changes=changes,section_bytes=offset,expected_section_bytes=offset,descriptor_rows=193184,fields=298,children=5,expected_schema_refusal='',expected_bridge_refusal='' if fault=='control' else 'SAVE_COMPONENT_METADATA',expected_bridge_prefix=False if fault=='control' else True,bypass_expected='' if fault not in ['field_type','field_extent'] else 'COLUMN_SHAPE'))
e=r/'docs/validation/evidence/field-policy-validation-planning-2026-09-20'
(e/'metadata-arithmetic-check.json').write_text(json.dumps(dict(schema_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),source_unchanged=True,kind='Python arithmetic check; not Godot execution',cases=out),indent=2)+'\n')
print(json.dumps(out,indent=2))
