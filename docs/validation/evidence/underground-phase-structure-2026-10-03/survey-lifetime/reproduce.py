from pathlib import Path
import tempfile,subprocess,shutil,importlib.util,re,sys
root=Path.cwd(); logs=Path(tempfile.mkdtemp(prefix='ug1075-check-')); print(logs,flush=True)
assets=root/'godot/demo/assets'; parked=logs/'assets-aside'; had=assets.exists()
if had: shutil.move(str(assets),str(parked))
try:
 cache=root/'godot/.godot'
 if cache.exists():shutil.rmtree(cache)
 with (logs/'import.log').open('w') as out: imported=subprocess.run(['godot','--headless','--path','godot','--editor','--quit'],stdout=out,stderr=subprocess.STDOUT)
 bad=[line for line in (logs/'import.log').read_text().splitlines() if re.search(r'^(?:SCRIPT ERROR|ERROR|WARNING):',line)];print('import exit',imported.returncode,'diagnostics',bad[:30],flush=True)
 if imported.returncode or bad:raise SystemExit(1)
 spec=importlib.util.spec_from_file_location('shards',root/'tools/ci_test_shards.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);count=len(m.discover(root));plan=m.make_plan(count,root)
 for name in sys.argv[1:]:
  index=next(i for i,shard in enumerate(plan['shards']) if name in shard)
  with (logs/(name+'.log')).open('w') as out: done=subprocess.run(['./tools/run_tests.sh','--shard',f'{index}/{count}','--output-dir',str(logs/(name+'-shard'))],stdout=out,stderr=subprocess.STDOUT)
  print(name,'exit',done.returncode,flush=True)
  for line in (logs/(name+'.log')).read_text().splitlines():
   if re.search(r'failure|assertion|diagnostics:|^log:|ERROR|WARNING|FAIL|error:',line):print(line,flush=True)
  if done.returncode:raise SystemExit(done.returncode)
finally:
 if had:shutil.move(str(parked),str(assets))
 print('assets restored',not had or assets.exists(),flush=True)
