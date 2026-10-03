from pathlib import Path
import sys,subprocess,shutil,hashlib,json,time
root=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(root/'tools'))
import ci_test_shards as shards
if len(sys.argv) != 2: raise SystemExit('usage: reproduce.py new-output-directory')
out=Path(sys.argv[1]).resolve()
out.mkdir(parents=True,exist_ok=False)
files=['godot/scripts/core/buildings.gd', 'godot/scripts/core/excavation_sites.gd', 'godot/scripts/core/underground_room_cut_map.gd', 'godot/scripts/core/underground_room_orders.gd', 'godot/scripts/core/underground_routes.gd', 'godot/scripts/core/underground_world_routes.gd', 'godot/scripts/core/underground_locations.gd', 'godot/test/test_buildings_spatial.gd', 'godot/test/test_excavation_physical.gd', 'godot/test/test_excavation_claim_batch.gd', 'godot/test/test_underground_room_cut_map.gd', 'godot/test/test_underground_room_orders.gd', 'godot/test/test_underground_room_bindings.gd', 'godot/test/test_underground_room_admission.gd', 'godot/test/test_underground_furniture_work.gd', 'godot/test/test_underground_furniture_batches.gd', 'godot/test/test_underground_routes.gd', 'godot/test/test_underground_world_routes.gd', 'godot/test/test_underground_locations.gd']
pins={s:hashlib.sha256((root/s).read_bytes()).hexdigest() for s in files}
(out/'source-sha256.json').write_text(json.dumps(pins,indent=2)+'\n')
assets=root/'godot/demo/assets'; backup=root.parent/(root.name+'-claims-paths-evidence-assets')
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
    for suite in ['test_buildings_spatial.gd', 'test_excavation_physical.gd', 'test_excavation_claim_batch.gd', 'test_underground_room_cut_map.gd', 'test_underground_room_orders.gd', 'test_underground_room_bindings.gd', 'test_underground_room_admission.gd', 'test_underground_furniture_work.gd', 'test_underground_furniture_batches.gd', 'test_underground_routes.gd', 'test_underground_world_routes.gd', 'test_underground_locations.gd']:
        index=next(i for i,g in enumerate(plan['shards']) if g==[suite])
        run(['./tools/run_tests.sh','--shard',f"{index}/{plan['shard_count']}",'--output-dir',str(out)],suite+'.log')
    run(['python3','tools/gdscript_warnings.py','--max','0','--port','6197',*files],'analyzer.log')
except Exception as e:
    status=1;record['error']=str(e)
finally:
    if backup.exists(): backup.rename(assets)
    record['assets_restored']=assets.exists()==record['assets_present_before']
    record['source_unchanged']=pins=={s:hashlib.sha256((root/s).read_bytes()).hexdigest() for s in files}
    if not record['assets_restored'] or not record['source_unchanged']: status=1
    record['exit_code']=status
    (out/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
sys.exit(status)
