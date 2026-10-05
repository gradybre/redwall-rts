#!/usr/bin/env python3
"""Focused official suite/analyzer with isolated userdata, clean import and restoration; no full-suite claim."""
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[4]
FILES = ['godot/scripts/ui/ui_resident_card.gd', 'godot/scripts/ui/ui_resident_snapshot.gd', 'godot/scripts/ui/ui_notices.gd', 'godot/scripts/systems/ui_manager.gd', 'godot/demo/ui/demo_stall_banner.gd', 'godot/scripts/ui/ui_specimen.gd']
SUITES = ['test_ui_resident_card.gd', 'test_ui_resident_snapshot.gd', 'test_ui_notices.gd', 'test_ui_manager.gd', 'test_demo_stall_banner.gd', 'test_ui_shell.gd']
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path, data): path.write_text(json.dumps(data,indent=2)+'\n')
def findings(text): return re.findall(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|(?:Parse|Parser) Error:|resources still in use at exit|ObjectDB instances? (?:were |was )?leaked',text,re.M)
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--out',required=True,type=Path); ap.add_argument('--port',type=int,default=6466)
    a=ap.parse_args(); out=a.out.resolve(); out.mkdir(parents=True,exist_ok=False)
    project=ROOT/'godot/project.godot'; original=project.read_bytes(); assets=ROOT/'godot/demo/assets'
    if assets.is_symlink(): raise ValueError('Refuse shared assets')
    paths=[p for p in (ROOT/'godot').rglob('*.gd') if '.godot' not in p.parts]
    before={str(p.relative_to(ROOT)):sha(p) for p in paths}; write(out/'source-before.json',before)
    sidecars={p:p.read_bytes() for ext in ('*.import','*.uid') for p in (ROOT/'godot').rglob(ext)}
    pin={name:sha(ROOT/name) for name in FILES}; write(out/'source-sha256.json',pin)
    for name in FILES: (out/(Path(name).name+'.txt')).write_bytes((ROOT/name).read_bytes())
    record={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'commands':[],
        'scope':'Six focused official UI suites plus entire zero-warning analyzer and raw editor gate; not a full-suite milestone',
        'assets_present_before':assets.exists(),'runtime_qualified':False}
    def run(cmd,logname):
        start=time.monotonic()
        with (out/logname).open('w') as stream: ret=subprocess.run(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=900)
        record['commands'].append({'command':cmd,'log':logname,'exit_code':ret.returncode,'seconds':round(time.monotonic()-start,3)})
        print(logname,ret.returncode,flush=True)
        if ret.returncode: raise RuntimeError(logname+' failed')
    status=1
    with tempfile.TemporaryDirectory(prefix='ug1177-assets-',dir=ROOT) as tmp:
        parked=Path(tmp)/'assets'
        try:
            assert b'config/use_custom_user_dir' not in original
            project.write_bytes(original.replace(b'[application]\n',('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-ug1177-'+hashlib.sha256(str(out).encode()).hexdigest()[:12]+'"\n').encode(),1))
            if assets.exists(): assets.rename(parked)
            shutil.rmtree(ROOT/'godot/.godot',ignore_errors=True)
            run(['godot','--headless','--path','godot','--editor','--quit'],'clean-import.log')
            record['import_findings']=findings((out/'clean-import.log').read_text())
            if record['import_findings']: raise RuntimeError('Import diagnostics')
            sys.path.insert(0,str(ROOT/'tools')); import ci_test_shards as shards
            plan=shards.make_plan(len(shards.discover(ROOT)),repo=ROOT,weights_path=ROOT/'tools/ci_test_shard_weights.json')
            record['suites']={}
            for suite in SUITES:
                index=next(i for i,group in enumerate(plan['shards']) if group==[suite])
                logname=suite+'.log'
                run(['./tools/run_tests.sh','--shard',f"{index}/{plan['shard_count']}",'--output-dir',str(out/suite)],logname)
                raw=(out/logname).read_text()
                counts,actual,_=shards.parse_log(raw)
                assert actual==[suite]
                record['suites'][suite]=counts
                for line in raw.splitlines():
                    if 'test(s),' in line or line.startswith(('diagnostics:', 'log:')): print(line,flush=True)
                if findings(raw): raise RuntimeError('Raw diagnostics in '+suite)
            run(['python3','tools/gdscript_warnings.py','--max','0','--port',str(a.port),'--json',str(out/'analyzer.json')],'analyzer.log')
            raw=Path(os.environ.get('TMPDIR','/tmp'))/f'gdscript_warnings_editor_{a.port}.log'
            shutil.copyfile(raw,out/'analyzer-editor.log'); record['analyzer_raw_findings']=findings(raw.read_text())
            if record['analyzer_raw_findings']: raise RuntimeError('Analyzer editor diagnostics')
            status=0
        except Exception as e: record['error']=repr(e)
        finally:
            project.write_bytes(original)
            if parked.exists(): parked.rename(assets)
            ownuids={ROOT/(name+'.uid') for name in FILES}
            for ext in ('*.import','*.uid'):
                for p in set((ROOT/'godot').rglob(ext))-set(sidecars)-ownuids: p.unlink()
            for p,data in sidecars.items(): p.write_bytes(data)
            after={str(p.relative_to(ROOT)):sha(p) for p in paths}
            write(out/'source-after.json',after)
            record.update(project_restored=project.read_bytes()==original,assets_restored=assets.exists()==record['assets_present_before'],sources_unchanged=after==before,old_sidecars_restored=all(p.read_bytes()==v for p,v in sidecars.items()))
            if not all(record[k] for k in ['project_restored','assets_restored','sources_unchanged','old_sidecars_restored']): status=1
            record['exit_code']=status;write(out/'invocation.json',record)
    return status
if __name__=='__main__': raise SystemExit(main())
