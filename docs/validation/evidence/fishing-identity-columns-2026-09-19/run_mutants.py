"""Parent mutation checks; run alone in the integration checkout, restore all bytes in finally."""
import hashlib,json,pathlib,re,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[4]
E=pathlib.Path(__file__).resolve().parent
F=ROOT/'godot/scripts/core/fishing.gd'; R=ROOT/'docs/planning/canonical_state_registry.json'; G=ROOT/'godot/scripts/core/canonical_state_hash.gd'
RUN=ROOT/'godot/test/fishing_identity_mutation_focus.gd'
assert not RUN.exists()
original={p:p.read_bytes() for p in [F,R,G]}
def replace(s,old,new):
 assert s.count(old)==1,(old,s.count(old))
 return s.replace(old,new)
def run(name,suites):
 RUN.write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray('+json.dumps(['res://test/'+x+'.gd' for x in suites])+')\n')
 p=subprocess.run(['godot','--headless','--path','godot','--script','test/fishing_identity_mutation_focus.gd'],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
 (E/(name+'.log')).write_text(p.stdout)
 m=re.search(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$',p.stdout,re.M)
 valid=bool(m) and int(m[1])>0 and 'SCRIPT ERROR:' not in p.stdout and 'Parse Error:' not in p.stdout
 return {'mutant':name,'exit_code':p.returncode,'killed':valid and p.returncode!=0 and int(m[3])>0,'summary':[x for x in p.stdout.splitlines() if '  FAIL ' in x or re.match(r'^\d+ test\(s\)',x)]}
selected=sys.argv[1:] or ["omit-slot-equality","reconstruct-reverse-map","omit-restored-slot","omit-canonical-slot"]
prior=E/"mutation-results.json"
results=[r for r in json.loads(prior.read_text())["results"] if r["mutant"] not in selected] if sys.argv[1:] and prior.exists() else []
try:
 for name in selected:
  for p,b in original.items(): p.write_bytes(b)
  s=F.read_text();suites=['test_fishing_claim_identity','test_resource_claim_columns']
  if name=='omit-slot-equality':
   s=replace(s,'if _effort_claim_expedition_slot[row] == expedition_ref.x \\\n\t\t\t\tand _effort_claim_expedition_generation[row] == expedition_ref.y:','if _effort_claim_expedition_generation[row] == expedition_ref.y:')
   s=replace(s,'if _effort_claim_expedition_slot[row] != expedition_ref.x \\\n\t\t\tor _effort_claim_expedition_generation[row] != expedition_ref.y:','if _effort_claim_expedition_generation[row] != expedition_ref.y:')
   F.write_text(s)
  elif name=='reconstruct-reverse-map':
   s=replace(s,'\treturn Vector2i(_effort_claim_expedition_slot[row], _effort_claim_expedition_generation[row])','\tvar slot: int = _directory.owner_slot_of_typed_row(EntityDirectory.KIND_EXPEDITION, row)\n\tif slot == EntityDirectory.NULL_SLOT:\n\t\treturn NULL_REF\n\treturn Vector2i(slot, _effort_claim_expedition_generation[row])');F.write_text(s)
  elif name=='omit-restored-slot':
   s=replace(s,'\t_effort_claim_expedition_slot = expedition_slot\n','\t# MUTANT: omit publication of restored owner slot.\n');F.write_text(s)
  else:
   j=json.loads(R.read_text());o=next(o for o in j['owners'] if o['owner_key']=='fishing' and o['section_id']==7);assert o['fields'][-1]['field_key']=='_effort_claim_expedition_slot';o['fields'].pop();j['record_count']-=1;j['packed_source_field_count']-=1;R.write_text(json.dumps(j,indent=2)+'\n');subprocess.run(['python3','tools/generate_canonical_state_table.py'],cwd=ROOT,check=True,stdout=subprocess.PIPE);suites=['test_canonical_state_hash']
  result=run(name,suites);results.append(result);print(json.dumps(result),flush=True)
  assert result['killed'],result
finally:
 for p,b in original.items(): p.write_bytes(b)
 RUN.unlink(missing_ok=True)
 pathlib.Path(str(RUN)+'.uid').unlink(missing_ok=True)
 restored={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in original}
 assert all(p.read_bytes()==b for p,b in original.items())
 (E/'mutation-results.json').write_text(json.dumps({'results':results,'restored_source_sha256':restored},indent=2)+'\n')
assert len(results)==4
