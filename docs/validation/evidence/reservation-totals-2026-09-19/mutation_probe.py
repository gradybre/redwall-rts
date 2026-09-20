from pathlib import Path
import hashlib,subprocess,json
root=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');source=root/'godot/scripts/core/reservations.gd';original=source.read_bytes();ev=root/'docs/validation/evidence/reservation-totals-2026-09-19'
runner=root/'godot/test/reservation_totals_mutation_focus.gd';assert not runner.exists()
runner.write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_reservation_totals.gd"])\n')
needle='\t\tif not IntMath.checked_add_into(total, _r_quantity_milli[row], out):\n\t\t\treturn false\n\t\ttotal = out.value'
replacement='\t\ttotal += _r_quantity_milli[row]'
assert original.decode().count(needle)==1
try:
 source.write_text(original.decode().replace(needle,replacement))
 with (ev/'mutation-skip-checked-add.log').open('w') as out:
  run=subprocess.run(['caffeinate','-i','godot','--headless','--path','godot','--script','res://test/reservation_totals_mutation_focus.gd'],cwd=root,stdout=out,stderr=subprocess.STDOUT,timeout=90)
 log=(ev/'mutation-skip-checked-add.log').read_text();assert run.returncode!=0 and '8 test(s)' in log and 'SCRIPT ERROR' not in log
 result={'mutant':'skip checked add, restore unchecked addition','exit_code':run.returncode,'killed':True,'summary':[x for x in log.splitlines() if 'test(s)' in x or 'FAIL' in x]}
finally:
 source.write_bytes(original);runner.unlink();runner.with_suffix('.gd.uid').unlink(missing_ok=True)
assert source.read_bytes()==original
result['restored_source_sha256']=hashlib.sha256(original).hexdigest();(ev/'mutation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
