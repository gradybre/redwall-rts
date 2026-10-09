#!/usr/bin/env python3
"""Official isolated UI suites against exactly accepted current source publication; restore all test inputs."""
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
HERE = Path(__file__).resolve().parent
FILES = ['godot/scripts/systems/ui_manager.gd', 'godot/scripts/ui/ui_world_session.gd',
         'godot/test/test_ui_manager.gd', 'godot/test/test_ui_world_session.gd']
BASE = 'godot/data/underground/mole-worker/'
PREREQUISITES = {
 BASE+'mole_profile_catalog.gd': 'd5f28ac82d76a97ad3f11763b36e0d7e42ce286624bf2c968511662b1a3aaa9e',
 BASE+'profile-publication-v3/catalog_source.gd': 'fca8e5410940b8dfa98a1e7796b4138f25464402e784de46447d020402c06e0c',
 BASE+'profile-publication-v3/manifest.json': '8f210e11768131779e6c825d7a3d2509cb32076aedd6891e6573489d1b6814c1',
 BASE+'profile-publication-v3/mole-worker.ugprof': 'a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204',
}
INPUTS = ['godot/data/underground/initial_level_pack.uglvl', BASE+
 'evidence/contact-qualification/install-program-compile-v3/result/mole-worker.ugactor',
 'tools/run_tests.sh', 'tools/ci_test_shards.py', 'tools/gdscript_warnings.py',
 'docs/persistence_state_registry.md'] + list(PREREQUISITES)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def write(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n')


def snapshot():
    paths = {p for folder in ('scripts','demo','test','data')
             for p in (ROOT/'godot'/folder).rglob('*.gd') if p.is_file()}
    paths.update(ROOT/name for name in INPUTS)
    paths.update([Path(__file__).resolve(), HERE/'registry-test-only-append.md'])
    return {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}


def raw_findings(text):
    return re.findall(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|(?:Parse|Parser) Error:|'
      r'resources still in use at exit|ObjectDB instances? (?:were |was )?leaked', text, re.M)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--prerequisite-root', type=Path, required=True)
    parser.add_argument('--port', type=int, default=6383)
    parser.add_argument('--suites', nargs='+', default=['test_ui_world_session.gd','test_ui_manager.gd'])
    args=parser.parse_args()
    if args.out.is_symlink() or args.out.exists(): raise ValueError('Output must be create-only and not a symlink')
    out=args.out.resolve()
    for name, expected in PREREQUISITES.items():
        if sha(args.prerequisite_root/name)!=expected: raise ValueError('Prerequisite drift: '+name)
    project=ROOT/'godot/project.godot'; original_project=project.read_bytes()
    registry=ROOT/'docs/persistence_state_registry.md'; original_registry=registry.read_bytes()
    appendix=(HERE/'registry-test-only-append.md').read_bytes()
    if b'### `godot/scripts/core/underground_world_retirement.gd`' in original_registry:
        raise ValueError('Permanent registry changed; review the test-only appendix before reuse')
    if b'config/use_custom_user_dir' in original_project or original_project.count(b'[application]\n')!=1:
        raise ValueError('Incompatible user-directory configuration')
    assets=ROOT/'godot/demo/assets'
    if assets.is_symlink(): raise ValueError('Refuse shared/symlink assets')
    originals={name:(ROOT/name).read_bytes() if (ROOT/name).exists() else None for name in PREREQUISITES}
    out.mkdir(parents=True, exist_ok=False)
    isolated='Redwall-ug1160-'+hashlib.sha256(str(out).encode()).hexdigest()[:16]
    test_project=original_project.replace(b'[application]\n', (
      '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+isolated+'"\n').encode(),1)
    original_pins=snapshot(); write(out/'original-inputs.json',original_pins)
    write(out/'diagnostic-prerequisites.json',{'source_root':str(args.prerequisite_root.resolve()),
      'sha256':PREREQUISITES,'scope':'accepted current publication temporarily composed; no consumer or source gate override'})
    write(out/'source-sha256.json',{name:sha(ROOT/name) for name in FILES})
    saved=out/'executed-source';saved.mkdir()
    for name in FILES: (saved/(Path(name).name+'.txt')).write_bytes((ROOT/name).read_bytes())
    (saved/'reproduce.py.txt').write_bytes(Path(__file__).read_bytes())
    (out/'registry-test-only-append.md').write_bytes(appendix)
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    record={'head_before':head,'commands':[],'custom_user_dir_name':isolated,
      'project_sha256_before':sha(project),'assets_present_before':assets.exists(),'runtime_qualified':False}
    sidecars={p:p.read_bytes() for ext in ('*.import','*.uid') for p in (ROOT/'godot').rglob(ext)}
    status=1;pins=None
    def run(command,log_name):
        start=time.monotonic()
        with (out/log_name).open('w') as log:
            result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=900)
        record['commands'].append({'command':command,'exit_code':result.returncode,
          'seconds':round(time.monotonic()-start,3),'log':log_name})
        print(log_name,result.returncode,flush=True)
        if result.returncode: raise RuntimeError(log_name+' failed')
    with tempfile.TemporaryDirectory(prefix='ug1160-assets-',dir=ROOT) as temporary:
        parked=Path(temporary)/'assets'
        try:
            project.write_bytes(test_project);registry.write_bytes(original_registry+appendix)
            for name in PREREQUISITES:
                path=ROOT/name
                if path.is_symlink(): raise ValueError('Refuse symlink prerequisite: '+name)
                path.parent.mkdir(parents=True,exist_ok=True)
                path.write_bytes((args.prerequisite_root/name).read_bytes())
            pins=snapshot();write(out/'inputs-before.json',pins)
            if assets.exists(): assets.rename(parked)
            shutil.rmtree(ROOT/'godot/.godot',ignore_errors=True)
            run(['godot','--headless','--path','godot','--editor','--quit'],'clean-import.log')
            record['import_raw_findings']=raw_findings((out/'clean-import.log').read_text())
            if record['import_raw_findings']: raise RuntimeError('Raw import diagnostic/leak')
            sys.path.insert(0,str(ROOT/'tools'));import ci_test_shards as shards
            plan=shards.make_plan(len(shards.discover(ROOT)),repo=ROOT,weights_path=ROOT/'tools/ci_test_shard_weights.json')
            record['strict_suites']={}
            for suite in args.suites:
                index=next(i for i,group in enumerate(plan['shards']) if group==[suite])
                log_name=suite+'.log'
                run(['./tools/run_tests.sh','--shard',f"{index}/{plan['shard_count']}",'--output-dir',str(out)],log_name)
                counts,actual,_=shards.parse_log((out/log_name).read_text())
                if actual!=[suite]: raise RuntimeError('Singleton suite census mismatch')
                record['strict_suites'][suite]=counts
            run(['python3','tools/gdscript_warnings.py','--max','0','--port',str(args.port),
                 '--json',str(out/'analyzer.json'),*FILES],'analyzer.log')
            status=0
        except (Exception,KeyboardInterrupt) as error: record['error']=repr(error)
        finally:
            after=snapshot();write(out/'inputs-after.json',after)
            record['executed_source_unchanged']=pins is not None and pins==after
            for name,data in originals.items():
                if data is None: (ROOT/name).unlink(missing_ok=True)
                else: (ROOT/name).write_bytes(data)
            project.write_bytes(original_project);registry.write_bytes(original_registry)
            if parked.exists(): parked.rename(assets)
            for ext in ('*.import','*.uid'):
                for path in set((ROOT/'godot').rglob(ext))-set(sidecars): path.unlink()
            for path,data in sidecars.items(): path.write_bytes(data)
            restored=snapshot();write(out/'restored-inputs.json',restored)
            record.update(project_restored=project.read_bytes()==original_project,
              registry_restored=registry.read_bytes()==original_registry,
              prerequisites_restored=all((ROOT/name).read_bytes()==data if data is not None else not (ROOT/name).exists()
                                        for name,data in originals.items()),
              prerequisite_sources_unchanged=all(sha(args.prerequisite_root/name)==expected for name,expected in PREREQUISITES.items()),
              assets_restored=assets.exists()==record['assets_present_before'],
              import_sidecars_restored=all(p.read_bytes()==data for p,data in sidecars.items()),
              original_sources_restored=restored==original_pins,
              head_unchanged=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==head)
            checks=('project_restored','registry_restored','prerequisites_restored','prerequisite_sources_unchanged',
              'assets_restored','import_sidecars_restored','executed_source_unchanged','original_sources_restored','head_unchanged')
            if not all(record[k] for k in checks): status=1
            record['exit_code']=status;write(out/'invocation.json',record)
    return status

if __name__=='__main__': raise SystemExit(main())
