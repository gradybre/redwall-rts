"""Run only after source review intake and other Godot work ends. Restore exact bytes in finally."""
import hashlib,json,pathlib,re,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[4]
E=pathlib.Path(__file__).resolve().parent
SOURCE=ROOT/'godot/scripts/core/save_resource_claims_reconcile.gd'
RUN=ROOT/'godot/test/claim_reconciliation_mutation_focus.gd'
assert not RUN.exists()
original=SOURCE.read_bytes()
def change(s,old,new,count=1):
 assert s.count(old)==count,(old,s.count(old))
 return s.replace(old,new)
results=[]
try:
 for name in ['skip-live-tick-provenance','skip-zero-claim-totals','double-count-shared-zone','reinterpret-stale-owner','skip-reverse-component-walk']:
  s=original.decode()
  if name=='skip-live-tick-provenance':
   s=change(s,'if created_tick != jobs.created_tick[row]:','if created_tick < 0:')
  elif name=='skip-zero-claim-totals':
   for field in ['habitat_total','zone_total']:
    old=f'\t\tvar total: int = sums.{field}[row]\n';s=change(s,old,old+'\t\tif total == 0:\n\t\t\tcontinue\n')
  elif name=='double-count-shared-zone':
   s=change(s,'if designation_row != basin_row:','if designation_row >= 0:')
  elif name=='reinterpret-stale-owner':
   start=s.index('static func _fishing_claim_gate(');end=s.index('static func _forage_claim_gate(')
   body=s[start:end];assert body.count('expedition_slot[row]')>=3;body=body.replace('expedition_slot[row]','reconstructed_slot')
   marker='\t\tvar owner_state: int = _pair_state(directory, reconstructed_slot,\n'
   replacement='\t\tvar reconstructed_slot: int = expedition_slot[row]\n\t\tvar replacement_slot: int = owner_map[base_expedition + row]\n\t\tif replacement_slot >= 0:\n\t\t\treconstructed_slot = replacement_slot\n'+marker
   body=change(body,marker,replacement);s=s[:start]+body+s[end:]
  else:
   s=change(s,'\treturn _reverse_component_gate(directory, components, out)','\treturn true # MUTANT: omit reverse Directory mirror verification.')
  SOURCE.write_text(s)
  RUN.write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_save_resource_claims_reconcile.gd","res://test/test_resource_claim_columns.gd"])\n')
  proc=subprocess.run(['godot','--headless','--path','godot','--script','test/claim_reconciliation_mutation_focus.gd'],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
  (E/(name+'.log')).write_text(proc.stdout)
  m=re.search(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$',proc.stdout,re.M)
  killed=bool(m) and int(m[1])>0 and int(m[3])>0 and proc.returncode!=0 and 'SCRIPT ERROR:' not in proc.stdout and 'Parse Error:' not in proc.stdout
  result={'mutant':name,'exit_code':proc.returncode,'killed':killed,'summary':[l for l in proc.stdout.splitlines() if '  FAIL ' in l or re.match(r'^\d+ test\(s\)',l)]};results.append(result);print(json.dumps(result),flush=True)
  SOURCE.write_bytes(original)
  assert killed,result
finally:
 SOURCE.write_bytes(original)
 RUN.unlink(missing_ok=True)
 pathlib.Path(str(RUN)+'.uid').unlink(missing_ok=True)
 assert SOURCE.read_bytes()==original
 (E/'mutation-results.json').write_text(json.dumps({'results':results,'restored_source_sha256':hashlib.sha256(original).hexdigest()},indent=2)+'\n')
assert len(results)==5
