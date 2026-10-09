from pathlib import Path
import sys,subprocess,shutil,hashlib,json,time
root=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(root/'tools'))
import ci_test_shards as shards
if len(sys.argv) != 2: raise SystemExit('usage: reproduce.py new-output-directory')
out=Path(sys.argv[1]).resolve()
out.mkdir(parents=True,exist_ok=False)
files=['godot/scripts/core/underground_work_face.gd','godot/test/test_underground_work_face.gd','godot/scripts/core/underground_terrain.gd','godot/test/test_underground_terrain.gd','godot/scripts/core/underground_final_facts.gd','godot/scripts/core/underground_space_owner.gd','godot/test/test_underground_final_facts.gd']
pins={s:hashlib.sha256((root/s).read_bytes()).hexdigest() for s in files}
(out/'source-sha256.json').write_text(json.dumps(pins,indent=2)+'\n')
assets=root/'godot/demo/assets'; backup=root.parent/(root.name+'-work-face-evidence-assets')
assert not backup.exists()
record={'assets_present_before':assets.exists(),'commands':[]}
status=0
def run(cmd,log):
    t=time.monotonic()
    with (out/log).open('w') as f: result=subprocess.run(cmd,cwd=root,stdout=f,stderr=subprocess.STDOUT)
    record['commands'].append({'command':cmd,'exit_code':result.returncode,'seconds':round(time.monotonic()-t,3),'log':log})
    print(log,result.returncode,flush=True)
    for line in (out/log).read_text().splitlines():
        if line.startswith(('diagnostics:','log:','ok:','error:')) or ' test(s),' in line or 'GDScript warning(s)' in line or 'SCRIPT ERROR:' in line: print(line,flush=True)
    if result.returncode: raise RuntimeError(log)
try:
    if assets.exists(): assets.rename(backup)
    shutil.rmtree(root/'godot/.godot',ignore_errors=True)
    run(['godot','--headless','--path','godot','--editor','--quit'],'clean-import.log')
    plan=shards.make_plan(len(shards.discover(root)),repo=root,weights_path=root/'tools/ci_test_shard_weights.json')
    for suite in ['test_underground_work_face.gd','test_underground_terrain.gd','test_underground_final_facts.gd']:
        index=next(i for i,g in enumerate(plan['shards']) if g==[suite])
        run(['./tools/run_tests.sh','--shard',f"{index}/{plan['shard_count']}",'--output-dir',str(out)],suite+'.log')
    run(['python3','tools/gdscript_warnings.py','--max','0','--port','6198',*files],'analyzer.log')
except Exception as e:
    status=1;record['error']=str(e)
finally:
    if backup.exists(): backup.rename(assets)
    record['assets_restored']=assets.exists()==record['assets_present_before']
    record['source_unchanged']=pins=={s:hashlib.sha256((root/s).read_bytes()).hexdigest() for s in files}
    record['exit_code']=status
    (out/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
sys.exit(status)
