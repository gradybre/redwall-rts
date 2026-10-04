#!/usr/bin/env python3
"""Exact clean CI-style focused1080 checks; unique create-only evidence directory."""
from pathlib import Path
import os,subprocess,tempfile,shutil,json,sys
root=Path(__file__).resolve().parents[4]
e=Path(sys.argv[1]).resolve();e.mkdir(parents=True,exist_ok=False)
assets=root/'godot/demo/assets';saved=root/'godot/demo/assets.profiles-clean-aside'
if saved.exists():raise RuntimeError('existing saved assets')
shimdir=Path(tempfile.mkdtemp(prefix='ug1080-profile-shim-'));shim=shimdir/'godot'
shim.write_text('#!/usr/bin/env python3\nimport os,sys\na=sys.argv[1:]\nfor i in range(len(a)-1):\n if a[i]=="--script" and a[i+1]=="test/run_tests.gd": a[i+1]='+repr(str(root/'tools/ci_test_shard_runner.gd'))+'\nos.execv("/opt/homebrew/bin/godot",["/opt/homebrew/bin/godot"]+a)\n');shim.chmod(0o755)
env=os.environ.copy();env['PATH']=str(shimdir)+os.pathsep+env['PATH'];env['REDWALL_TEST_SHARD_SUITES']=json.dumps(['test_underground_profiles.gd'])
codes=[]
commands=[['/opt/homebrew/bin/godot','--headless','--path','godot','--editor','--quit'],['./tools/run_tests.sh'],['python3','tools/gdscript_warnings.py','--port','6149','--max','0','godot/scripts/core/underground_profiles.gd','godot/test/test_underground_profiles.gd']]
try:
 if assets.exists():assets.rename(saved)
 shutil.rmtree(root/'godot/.godot',ignore_errors=True)
 for command,name in zip(commands,['import','strict','analyzer']):
  with (e/(name+'.log')).open('w') as out:code=subprocess.call(command,cwd=root,env=env,stdout=out,stderr=subprocess.STDOUT)
  codes.append(code);print(name,code,flush=True)
  if code:break
finally:
 if saved.exists():saved.rename(assets)
 shutil.rmtree(shimdir)
 (e/'invocation.json').write_text(json.dumps({'commands':commands,'returncodes':codes,'selector':env['REDWALL_TEST_SHARD_SUITES']},indent=2)+'\n')
sys.exit(max(codes) if codes else 1)
