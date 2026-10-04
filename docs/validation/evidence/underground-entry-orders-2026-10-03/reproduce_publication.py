from pathlib import Path
import sys, subprocess, shutil, json, hashlib, time
root = Path.cwd()
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=False)
source = ['godot/scripts/core/underground_entry_plan.gd', 'godot/scripts/core/underground_room_orders.gd', 'godot/scripts/core/excavation_sites.gd', 'godot/scripts/core/underground_space_owner.gd', 'godot/scripts/core/underground_final_facts.gd', 'godot/test/test_underground_entry_orders.gd', 'godot/test/test_underground_furniture_work.gd', 'godot/test/test_underground_space_owner.gd', 'godot/test/test_underground_final_facts.gd']
pins = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in source}
(out/'source-sha256.json').write_text(json.dumps(pins, indent=2)+'\n')
assets = root/'godot/demo/assets'
backup = root.parent/'redwall-ug-1108-orders-assets'
assert not backup.exists()
had = assets.exists()
records = []
status = 0
sys.path.insert(0, str(root/'tools'))
import ci_test_shards as ci
plan = ci.make_plan(len(ci.discover()))
suites = ['test_underground_entry_orders.gd', 'test_underground_room_orders.gd', 'test_underground_room_admission.gd', 'test_underground_room_bindings.gd', 'test_excavation_entry_claim_batch.gd', 'test_excavation_claim_batch.gd', 'test_underground_space_owner.gd', 'test_underground_final_facts.gd', 'test_underground_furniture_work.gd']
def run(command, name):
    start = time.monotonic()
    with (out/name).open('w') as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
    records.append({'command': command, 'exit_code': result.returncode, 'seconds': round(time.monotonic()-start, 3), 'log': name})
    print(name, result.returncode, flush=True)
    if result.returncode:
        print((out/name).read_text()[-14000:])
        raise RuntimeError(name)
    for line in (out/name).read_text().splitlines():
        if line.startswith(('diagnostics:', 'log:', 'ok:')) or ' test(s),' in line or 'GDScript warning(s)' in line:
            print(line, flush=True)
try:
    if had:
        assets.rename(backup)
    shutil.rmtree(root/'godot/.godot', ignore_errors=True)
    run(['godot', '--headless', '--path', 'godot', '--editor', '--quit'], 'clean-import.log')
    for suite in suites:
        index = next(i for i, group in enumerate(plan['shards']) if group == [suite])
        spec = str(index)+'/'+str(plan['shard_count'])
        run(['./tools/run_tests.sh', '--shard', spec, '--output-dir', str(out/'shards')], suite+'.log')
    run(['python3', 'tools/gdscript_warnings.py', '--max', '0', '--port', '6291', '--json', str(out/'analyzer.json'), *source], 'analyzer.log')
except Exception as error:
    status = 1
    print(str(error), flush=True)
finally:
    if backup.exists():
        backup.rename(assets)
    result = {'commands': records, 'assets_restored': assets.exists()==had, 'source_unchanged': pins=={p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in source}, 'exit_code': status}
    (out/'commands.json').write_text(json.dumps(result, indent=2)+'\n')
sys.exit(status)
