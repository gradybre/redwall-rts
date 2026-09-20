"""Run only after review has released source and no heavy job is running."""
from pathlib import Path
import subprocess, hashlib, json, re
root=Path(__file__).resolve().parents[4]
ev=Path(__file__).resolve().parent
sources={n:root/f'godot/scripts/core/{n}.gd' for n in ['fishing','forage']}
original={n:p.read_bytes() for n,p in sources.items()}
runner=root/'godot/test/resource_claim_columns_mutation_focus.gd'
assert not runner.exists()
mutants=[
 ('drop-forage-order-key','forage','\t_claim_created_tick = created_tick\n','\t_claim_created_tick = created_tick\n\t_claim_created_tick.fill(0)\n'),
 ('rewrite-fishing-effort','fishing','\t_effort_claim_count = tally.active_rows\n','\t_effort_claim_count = tally.active_rows\n\t_habitat_effort_used.fill(0)\n'),
 ('skip-forage-amount-bound','forage','if remaining_milli[row] < 1 or remaining_milli[row] > MANUAL_QUOTA_MAX_MILLI:','if remaining_milli[row] < 1:'),
 ('skip-fishing-amount-bound','fishing','if slot_count[row] < 1 or slot_count[row] > slot_ceiling:','if slot_count[row] < 1:')]
runner.write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_resource_claim_columns.gd"])\n')
results=[]
try:
 for name,module,needle,replacement in mutants:
  for n,p in sources.items():p.write_bytes(original[n])
  raw=original[module].decode();assert raw.count(needle)==1,(name,raw.count(needle))
  sources[module].write_text(raw.replace(needle,replacement))
  with (ev/(name+'.log')).open('w') as out:
   p=subprocess.run(['caffeinate','-i','godot','--headless','--path','godot','--script','res://test/resource_claim_columns_mutation_focus.gd'],cwd=root,stdout=out,stderr=subprocess.STDOUT,timeout=120)
  log=(ev/(name+'.log')).read_text()
  assert p.returncode!=0 and re.search(r'\d+ test\(s\)',log) and 'SCRIPT ERROR' not in log,name
  result={'mutant':name,'exit_code':p.returncode,'killed':True,'summary':[x for x in log.splitlines() if 'test(s)' in x or 'FAIL' in x]}
  results.append(result);print(json.dumps(result),flush=True)
finally:
 for n,p in sources.items():p.write_bytes(original[n])
 runner.unlink();runner.with_suffix('.gd.uid').unlink(missing_ok=True)
assert all(p.read_bytes()==original[n] for n,p in sources.items())
(ev/'mutation-results.json').write_text(json.dumps({'results':results,'restored_source_sha256':{n:hashlib.sha256(raw).hexdigest() for n,raw in original.items()}},indent=2)+'\n')
