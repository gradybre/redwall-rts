from pathlib import Path
import sys, subprocess, shutil, json, hashlib, time
root = Path.cwd()
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=False)
source = ['godot/scripts/core/underground_entry_bindings.gd', 'godot/test/test_underground_entry_bindings.gd']
pins = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in source}
(out/'source-sha256.json').write_text(json.dumps(pins, indent=2)+'\n')
assets = root/'godot/demo/assets'
backup = root.parent/'redwall-ug-1111-entry-bindings-assets'
assert not backup.exists()
had = assets.exists()
records = []
status = 0
sys.path.insert(0, str(root/'tools'))
import ci_test_shards as ci
plan = ci.make_plan(len(ci.discover()))
suites = ['test_underground_entry_bindings.gd', 'test_underground_entry_placements.gd']
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
project = root/'godot/project.godot'
project_before = project.read_bytes()
project_hash = hashlib.sha256(project_before).hexdigest()
isolated = project_before.replace(b'[application]\n', b'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-ug-entry-bindings-tests"\n', 1)
assert isolated != project_before and b'config/use_custom_user_dir=' not in project_before
try:
    project.write_bytes(isolated)
    if had:
        assets.rename(backup)
    shutil.rmtree(root/'godot/.godot', ignore_errors=True)
    run(['godot', '--headless', '--path', 'godot', '--editor', '--quit'], 'clean-import.log')
    for suite in suites:
        index = next(i for i, group in enumerate(plan['shards']) if group == [suite])
        spec = str(index)+'/'+str(plan['shard_count'])
        run(['./tools/run_tests.sh', '--shard', spec, '--output-dir', str(out/'shards')], suite+'.log')
    run(['python3', 'tools/gdscript_warnings.py', '--max', '0', '--port', '6294', '--json', str(out/'analyzer.json'), *source], 'analyzer.log')
except Exception as error:
    status = 1
    print(str(error), flush=True)
finally:
    project.write_bytes(project_before)
    if backup.exists():
        backup.rename(assets)
    result = {'commands': records, 'isolated_user_dir': 'Redwall-ug-entry-bindings-tests', 'project_before_sha256': project_hash, 'project_after_sha256': hashlib.sha256(project.read_bytes()).hexdigest(), 'assets_restored': assets.exists()==had, 'source_unchanged': pins=={p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in source}, 'exit_code': status}
    (out/'commands.json').write_text(json.dumps(result, indent=2)+'\n')
sys.exit(status)
