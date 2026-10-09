#!/usr/bin/env python3
"""Strict focused integration, using the real CI singleton shard gates and clean import."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[4]
SUITES = ['test_mole_qualified_profiles.gd', 'test_demo_profile_pack.gd',
          'test_underground_motion_catalog.gd', 'test_underground_motion_clock.gd',
          'test_underground_session.gd', 'test_underground_host.gd',
          'test_underground_room_world_phases.gd', 'test_underground_room_frontier.gd',
          'test_underground_connector_contacts.gd', 'test_underground_connector_delivery.gd',
          'test_underground_profiles.gd', 'test_mole_profile_driver.gd']


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--suite', action='append')
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    sys.path.insert(0, str(ROOT / 'tools'))
    import ci_test_shards as shards
    names = [path for path in (ROOT / 'godot').rglob('*') if path.is_file()
             and '.godot' not in path.parts and path.suffix in ('.gd', '.ugprof', '.ugmotion', '.uganim')]
    digest = lambda: {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in names}
    pins = digest()
    (out / 'source-sha256.json').write_text(json.dumps(pins, indent=2) + '\n')
    record = {'head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'scope': 'Focused integration, not the required full no-argument milestone suite.', 'commands': []}
    assets = ROOT / 'godot/demo/assets'
    project = ROOT / 'godot/project.godot'
    original = project.read_bytes()
    assert b'config/use_custom_user_dir' not in original
    isolated = original.replace(b'[application]\n', b'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-ug-profile-integration-20261004"\n', 1)
    record['assets_present_before'] = assets.exists()
    def run(command, name):
        start = time.monotonic()
        print('starting', name, flush=True)
        with (out/name).open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        record['commands'].append({'command': command, 'exit_code': result.returncode,
                                  'seconds': round(time.monotonic()-start,3), 'log': name})
        text = (out/name).read_text()
        for line in text.splitlines():
            if line.startswith(('diagnostics:', 'log:', 'ok:', 'error:', 'SCRIPT ERROR:')) or ' test(s),' in line or 'GDScript warning(s)' in line:
                print(line, flush=True)
        if result.returncode: raise RuntimeError(name)
        return text
    status = 0
    temporary = Path(tempfile.mkdtemp(prefix='ug-profile-integration-assets-', dir=ROOT.parent))
    parked = temporary / 'assets'
    try:
        project.write_bytes(isolated)
        if assets.exists(): assets.rename(parked)
        shutil.rmtree(ROOT/'godot/.godot', ignore_errors=True)
        raw = run(['godot','--headless','--path','godot','--editor','--quit'], 'clean-import.log')
        if re.search(r'(?:ERROR:|WARNING:|Parse Error:|Parser Error:|resources still in use|ObjectDB instances? (?:were|was) leaked)',raw):
            raise RuntimeError('clean import diagnostic')
        plan = shards.make_plan(len(shards.discover(ROOT)), repo=ROOT, weights_path=ROOT/'tools/ci_test_shard_weights.json')
        for suite in args.suite or SUITES:
            index = next(i for i, group in enumerate(plan['shards']) if group == [suite])
            run(['./tools/run_tests.sh','--shard',f"{index}/{plan['shard_count']}",'--output-dir',str(out)], suite+'.log')
        record['completed_suites'] = args.suite or SUITES
    except Exception as error:
        status = 1
        record['error'] = str(error)
        print('refused:', error, flush=True)
    finally:
        project.write_bytes(original)
        if parked.exists():
            if assets.exists(): assets.rename(out/'unexpected-generated-assets')
            parked.rename(assets)
        record['project_restored'] = project.read_bytes() == original
        record['assets_restored'] = assets.exists() == record['assets_present_before']
        record['source_unchanged'] = digest() == pins
        if not all(record[k] for k in ('project_restored','assets_restored','source_unchanged')): status = 1
        record['exit_code'] = status
        (out/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
        temporary.rmdir()
    return status


if __name__ == '__main__':
    raise SystemExit(main())
