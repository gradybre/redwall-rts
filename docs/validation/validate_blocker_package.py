#!/usr/bin/env python3
"""Reproduce documented contract checks; writes clearly scoped evidence and synthetic vectors."""
from pathlib import Path
import json,hashlib,struct,math,re,subprocess,datetime
R=Path(__file__).resolve().parents[2]
report={'scope':'Documentation, source-registry coverage and independent arithmetic/byte-framing checks only. No runtime tests or performance qualification.','checks':[]}
def check(name,condition,detail=None):
 report['checks'].append({'name':name,'passed':bool(condition),'detail':detail})
 if not condition: raise AssertionError(name)
a=json.loads((R/'docs/planning/asset_dimensions_and_budgets.json').read_text())
md=(R/'docs/planning/asset_dimensions_and_budgets.md').read_text()
cat=json.loads((R/'godot/data/catalog_ids.json').read_text())['domains']
check('All BuildingDefinition keys have one height envelope',set(a['buildings_top_u'])==set(cat['BuildingDefinition']),{'count':len(a['buildings_top_u'])})
for key,u in a['buildings_top_u'].items():
 check('Height row '+key,f'| {key} | {u} | {u/1024:g} |' in md)
for key,u in a['heights_candidate_u'].items():
 check('Species candidate '+key,f'| {key} | {u} |' in md)
for b in a['budgets']:
 row='| '+' | '.join(str(b[k]) for k in ['family','near_tri','mid_tri','far_tri','surfaces','max_texture_edge'])+' |'
 check('Budget row '+b['family'],row in md and b['near_tri']>=b['mid_tri']>=b['far_tri'])
check('Crop4096 tile arithmetic',[a['crop_module_triangles'][k]*4096 for k in ['near','mid','far']]==[1048576,393216,65536])
mip_bytes=sum((2**i)**2*4*3 for i in range(12))
check('2048 three-map RGBA8 full mip accounting',mip_bytes==67108860 and mip_bytes*4<=a['noncreature_texture_bytes'],{'one_set_bytes':mip_bytes,'four_sets_bytes':mip_bytes*4})
check('L0 hysteresis',math.isclose(64*1.1,a['settlement_l0']['promote_px']) and math.isclose(64*.9,a['settlement_l0']['demote_below_px']) and a['settlement_l0']['cap']==24)
check('Save descriptor table end',256+15*64==1216)
check('Section11 capacity framing',8+32*64==2056)
check('Chronicle page accounting',2*64*24==3072)
u32=lambda n:struct.pack('<I',n)
s=lambda v:u32(len(v.encode('utf-8')))+v.encode('utf-8')
for value,expected in [('','00000000'),('Oak','030000004f616b'),('Móle','050000004dc3b36c65')]:
 check('UTF8 framing '+repr(value),s(value).hex()==expected)
for raw in [b'\xc0',b'\xc0\x80',b'\xed\xa0\x80']:
 try: raw.decode('utf-8',errors='strict'); ok=False
 except UnicodeDecodeError: ok=True
 check('Malformed UTF8 '+raw.hex(),ok)
# Synthetic examples, not live compatibility identities.
fixtures={
 'rules_one_string':b'RWL-RULES-1\0'+u32(1)+s('ruleset.id')+b'\x05'+u32(1)+s('settlement_rules_v2'),
 'lookup_one_i32_table':b'RWL-LOOKUP-1\0'+u32(1)+s('fixture.values')+b'\x02'+u32(3)+struct.pack('<iii',-1,0,1024),
 'map_procedural_fixture':b'RWL-MAP-1\0'+struct.pack('<IiI',1,20260905,1)+bytes(32),
 'engine_reported_build_fixture':b'4.7.2.stable.official.ed1daf0bf001b61586d9930840f2f1394092c079\n'}
fixtures['state_empty_registry_framing_only']=(b'RWL-STATE-1'+bytes(128)+s(fixtures['engine_reported_build_fixture'].decode('utf-8'))+struct.pack('<qI',0,0))
check('State domain is11 bytes without terminator',len(b'RWL-STATE-1')==11)
check('Static hysteresis boundaries',a['static_lod']['promote_near_px']==198 and a['static_lod']['demote_near_below_px']==162 and math.isclose(48*1.1,a['static_lod']['promote_mid_px']) and math.isclose(48*.9,a['static_lod']['demote_mid_below_px']))
check('Multipart building budget',a['building_material_count']==4 and a['building_surfaces_by_lod']=={'near':16,'mid':16,'far':4})
check('Durable source brief path',(R/a['source_lookdev_brief']['path']).is_file())
v={'status':'SYNTHETIC_CODEC_TEST_VECTORS_NOT_PRODUCTION_DIGESTS','encoding':'SAVE-R09-003','vectors':{k:{'hex':v.hex(),'byte_length':len(v),'sha256':hashlib.sha256(v).hexdigest()} for k,v in fixtures.items()}}
(R/'docs/planning/save_identity_test_vectors.json').write_text(json.dumps(v,indent=2)+'\n')
newdocs=['docs/planning/asset_dimensions_and_budgets.md','docs/rulings/2026-09-11_save_codec_contract.md','docs/rulings/2026-09-11_focus_and_rollback_state.md','docs/rulings/2026-09-11_movement_gate_followthrough.md','docs/rulings/2026-09-11_asset_save_movement_blockers.md','docs/decisions/0080-asset-save-and-focus-engineering-contracts.md']
for name in newdocs:
 p=R/name
 for target in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if target.startswith(('https://','http://','#')): continue
  local=target.split('#')[0]
  # Validation result is written below.
  if local.endswith('2026-09-11_asset_save_movement_validation.json'):continue
  check('Relative link '+name+' -> '+local,(p.parent/local).exists())
reg=subprocess.run(['python3','docs/validation/state_registry_coverage.py'],cwd=R,capture_output=True,text=True)
check('State registry coverage',reg.returncode==0,reg.stdout.strip()+reg.stderr.strip())
diff=subprocess.run(['git','-c','filter.lfs.required=false','-c','filter.lfs.smudge=','-c','filter.lfs.process=','diff','--check','--','docs'],cwd=R,capture_output=True,text=True)
check('Documentation diff whitespace',diff.returncode==0,diff.stdout.strip()+diff.stderr.strip())
report['result']='PASS'
report['checked_at_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
report['source_brief_sha256']=hashlib.sha256((R/'docs/art-reference/world_art_lookdev_brief.md').read_bytes()).hexdigest()
report['asset_json_sha256']=hashlib.sha256((R/'docs/planning/asset_dimensions_and_budgets.json').read_bytes()).hexdigest()
report['not_tested']=['Godot runtime changes (none authored in this turn)','Production codec interoperability and continuation','Rendered comparison/proportion approval','Asset exports','Expanded MOVE gates','Windows/minimum-hardware performance']
(R/'docs/rulings/2026-09-11_asset_save_movement_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'result':report['result'],'checks':len(report['checks']),'registry':reg.stdout.strip(),'vector_count':len(fixtures)},indent=2))
