"""Bounded negative controls with source restoration and owned-runner cleanup."""
import hashlib,json,re,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[4]
source=root/'godot/scripts/core/reservations.gd'
original=source.read_text()
evidence=Path(__file__).resolve().parent
runner=root/'godot/test/.reservations_mutation_focus.gd'
assert not runner.exists()
runner.write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_reservations_columns.gd"])\n')
mutants=[('omit-source-derived-check','\tif not _reservation_derived_matches(derived):\n\t\treturn _refuse_column(COLUMN_RESERVATION_SOURCE_DERIVED)\n',''),('reverse-purpose-order','\t\treturn k3[a] < k3[b]','\t\treturn k3[a] > k3[b]'),('omit-lot-overflow-guard','\t\tif quantity_milli[row] > RESERVATION_MAX_I64 - total:\n\t\t\treturn COLUMN_RESERVATION_OVERFLOW\n','')]
results=[]
try:
 for name,old,new in mutants:
  assert original.count(old)==1,(name,original.count(old))
  source.write_text(original.replace(old,new,1))
  result=subprocess.run(['godot','--headless','--path','godot','--script','test/.reservations_mutation_focus.gd'],cwd=root,capture_output=True,text=True,timeout=120)
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
