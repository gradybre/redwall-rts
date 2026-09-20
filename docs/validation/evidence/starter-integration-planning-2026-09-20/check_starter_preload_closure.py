from pathlib import Path
import json,hashlib,re
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/starter-integration-planning-2026-09-20';p=e/'candidate-starter_structures.gd';s=p.read_text();clean=re.sub(r'""".*?"""','',s,flags=re.S);clean='\n'.join(x.split('#',1)[0] for x in clean.splitlines());constructors=re.findall(r'\b([A-Za-z_][A-Za-z0-9_.]*)\.new\(',clean);assert constructors==['Plan'],constructors
fields=re.findall(r'^\tvar ([a-z_]+): PackedInt32Array',s,re.M);assert fields==['buildings','rooms','room_tiles','furniture','footprints','candidate_access_tiles','edges','exit_tiles','bed_furniture_ordinals','header'],fields
publish=clean.split('func _publish(',1)[1].split('static func ',1)[0];assignments=re.findall(r'^\tout\.([a-z_]+) = staged\.([a-z_]+)$',publish,re.M);assert assignments==[(x,x) for x in fields];assert '.duplicate(' not in publish
seen={};edges=[];queue=[(str(p.relative_to(r)),s)]
while queue:
 name,text=queue.pop()
 if name in seen:continue
 seen[name]=hashlib.sha256(text.encode()).hexdigest()
 for dep in re.findall(r'preload\("res://([^\"]+\.gd)"\)',text):
  target='godot/'+dep;edges.append([name,target]);queue.append((target,(r/target).read_text()))
record={'scope':'Candidate constructor/publication and transitive preload source inspection; not native or RSS measurement','candidate_sha256':hashlib.sha256(s.encode()).hexdigest(),'candidate_constructor_calls':constructors,'packed_fields':fields,'cow_publication_fields':[x for x,y in assignments],'logical_plan_payload':2480,'maximum_simultaneous_plan_payload':4960,'preload_source_hashes':seen,'preload_edges':edges,'remaining':'Independent functional/metadata tests, review, final integration identity and full checks'}
(e/'candidate-preload-closure.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'constructor_calls':constructors,'packed_fields':len(fields),'cow_assignments':len(assignments),'source_modules':len(seen)}))
