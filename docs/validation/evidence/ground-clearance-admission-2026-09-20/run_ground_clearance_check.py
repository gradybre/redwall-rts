"""Capture bounded actual candidate checks with source identity and strict completion."""
from pathlib import Path
import sys,json,hashlib,subprocess,time,re
R=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19')
E=R/'docs/validation/evidence/ground-clearance-admission-2026-09-20'
label,kind=sys.argv[1:];assert re.fullmatch('[a-z0-9-]+',label)
assert kind in ('import','focus','full')
assert not (E/(label+'.json')).exists() and not (E/(label+'.log')).exists()
paths=['godot/scripts/core/movement.gd','godot/scripts/core/navigation.gd','godot/test/test_movement.gd','godot/test/test_movement_readmission.gd','godot/test/fixtures/synthetic_ground_movement.gd','godot/test/test_movement_clearance.gd','godot/test/ground_clearance_focus.gd']
def identity():return {p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in paths}
before=identity();start=time.monotonic();timed_out=False
cmd={'import':['godot','--headless','--path','godot','--editor','--quit'],'focus':['godot','--headless','--path','godot','--script','res://test/ground_clearance_focus.gd'],'full':['./tools/run_tests.sh']}[kind]
try:
 p=subprocess.run(cmd,cwd=R,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=600 if kind=='full' else 180);output=p.stdout;code=p.returncode
except subprocess.TimeoutExpired as ex:
 output=ex.stdout or '';output=output.decode() if isinstance(output,bytes) else output;code=None;timed_out=True
(E/(label+'.log')).write_text(output)
counts=re.findall(r'(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)',output);counts=list(map(int,counts[-1])) if counts else None
# Existing shutdown diagnostics must be recorded, not confused with script/parse failures.
errors=[line for line in output.splitlines() if re.search('SCRIPT ERROR:|Parse Error:|ERROR:',line)]
baseline=all('resources still in use at exit' in x for x in errors)
after=identity();passed=code==0 and not timed_out and before==after and (not errors or (kind=='full' and baseline)) and (kind=='import' or (counts is not None and counts[0]>0 and counts[1]>0 and counts[2]==0))
record={'kind':kind,'command':cmd,'source_sha256':before,'source_unchanged':before==after,'seconds':round(time.monotonic()-start,3),'exit_code':code,'timed_out':timed_out,'counts':counts,'engine_errors':errors,'passed':passed,'log_sha256':hashlib.sha256(output.encode()).hexdigest(),'scope':'Candidate verification only; independent review and exact committed CI required'}
(E/(label+'.json')).write_text(json.dumps(record,indent=2)+'\n');print(output[-3000:]);print(json.dumps(record));sys.exit(0 if passed else 1)
