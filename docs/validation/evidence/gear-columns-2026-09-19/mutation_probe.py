"""Bounded negative controls. Only run after the read-only review releases its inputs."""
from pathlib import Path
import subprocess,hashlib,json
root=Path(__file__).resolve().parents[4]
ev=Path(__file__).resolve().parent
source=root/'godot/scripts/core/gear.gd'
original=source.read_bytes()
runner=root/'godot/test/gear_columns_mutation_focus.gd'
assert not runner.exists()
mutants=[('drop-equipped-restore','\t_equipped = equipped\n','\t_equipped = equipped\n\t_equipped.fill(0)\n'),('skip-duplicate-lot','\treturn _gear_duplicate_lot_refusal(rows, occupied, lot_slot)','\treturn REFUSE_NONE'),('skip-source-derived','\tvar derived: StringName = _gear_source_derived_refusal(tally)','\tvar derived: StringName = REFUSE_NONE')]
runner.write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_gear_columns.gd"])\n')
results=[]
try:
 for name,needle,replacement in mutants:
  assert original.decode().count(needle)==1,(name,original.decode().count(needle))
  source.write_text(original.decode().replace(needle,replacement))
  with (ev/(name+'.log')).open('w') as out:
   p=subprocess.run(['caffeinate','-i','godot','--headless','--path','godot','--script','res://test/gear_columns_mutation_focus.gd'],cwd=root,stdout=out,stderr=subprocess.STDOUT,timeout=90)
  log=(ev/(name+'.log')).read_text()
  assert p.returncode!=0 and '23 test(s)' in log and 'SCRIPT ERROR' not in log,name
  result={'mutant':name,'exit_code':p.returncode,'killed':True,'summary':[x for x in log.splitlines() if 'test(s)' in x or 'FAIL' in x]}
  results.append(result);print(json.dumps(result),flush=True)
finally:
 source.write_bytes(original);runner.unlink();runner.with_suffix('.gd.uid').unlink(missing_ok=True)
assert source.read_bytes()==original
(ev/'mutation-results.json').write_text(json.dumps({'results':results,'restored_source_sha256':hashlib.sha256(original).hexdigest()},indent=2)+'\n')
