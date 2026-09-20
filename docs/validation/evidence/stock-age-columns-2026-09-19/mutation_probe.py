"""Bounded local negative controls; restore source and remove owned runner in finally."""
import hashlib,json,re,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[4]
source=root/'godot/scripts/core/stock_age.gd'
original=source.read_text()
evidence=Path(__file__).resolve().parent
runner=root/'godot/test/.stock_age_mutation_focus.gd'
assert not runner.exists()
runner.write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_stock_age_columns.gd"])\n')
guard='\tif not _column_payload_ok(_c_storage_class, _c_heated_interior, _c_declared_generation,\n\t\t\t_declared_slots, _declared_count):\n\t\treturn _refuse_column(COLUMN_STOCK_AGE_RECORD)\n'
mutants=[('omit-capture-payload',guard,''),('omit-restore-latch','\t_last_hour_tick = columns.last_hour_tick\n',''),('omit-restore-cache-reset','\t_spoiled_food_id = -1\n\t_compost_id = -1\n\t_last_column_refusal = REFUSE_NONE','\t_last_column_refusal = REFUSE_NONE')]
results=[]
try:
 for name,old,new in mutants:
  assert original.count(old)==1,(name,original.count(old))
  source.write_text(original.replace(old,new,1))
  result=subprocess.run(['godot','--headless','--path','godot','--script','test/.stock_age_mutation_focus.gd'],cwd=root,capture_output=True,text=True,timeout=120)
  output=result.stdout+result.stderr
  (evidence/(name+'.log')).write_text(output)
  summaries=re.findall(r'(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)',output)
  assert summaries and int(summaries[-1][0])>0 and int(summaries[-1][2])>0 and 'SCRIPT ERROR:' not in output,(name,output[-2000:])
  results.append({'name':name,'exit_code':result.returncode,'summary':summaries[-1],'killed':True})
finally:
 source.write_text(original)
 runner.unlink()
 (evidence/'mutation-results.json').write_text(json.dumps({'source_sha256':hashlib.sha256(original.encode()).hexdigest(),'results':results,'source_restored':source.read_text()==original},indent=2)+'\n')
print(json.dumps(results))
