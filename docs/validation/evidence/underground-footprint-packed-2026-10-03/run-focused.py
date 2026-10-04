import importlib.util,pathlib,subprocess,sys
spec=importlib.util.spec_from_file_location('shards','tools/ci_test_shards.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
n=len(m.discover());plan=m.make_plan(n)
p=pathlib.Path(sys.argv[1]);p.mkdir(exist_ok=True)
for target in sys.argv[2:]:
 i=next(i for i,g in enumerate(plan['shards']) if target in g)
 path=(p/target).with_suffix('.log')
 with path.open('w') as log:
  r=subprocess.run(['./tools/run_tests.sh','--shard',f'{i}/{n}','--output-dir',str(p)],stdout=log,stderr=subprocess.STDOUT)
 print(target,flush=True)
 detail=0
 for line in path.read_text().splitlines():
  if 'FAIL ' in line: detail=12
  if detail or 'test(s)' in line or 'diagnostics:' in line or line.startswith(('log:','ok:','error:','ERROR','SCRIPT ERROR','UG06_')):
   print(line[:1000],flush=True)
  if detail:detail-=1
 if r.returncode:sys.exit(r.returncode)
