from pathlib import Path
import subprocess,shutil,hashlib,json,time,sys
root=Path(__file__).resolve().parents[6]
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
if len(sys.argv)!=2: raise SystemExit('usage: reproduce.py fresh-output-directory')
out=Path(sys.argv[1]).resolve()
out.mkdir(parents=True,exist_ok=False)
files=subprocess.check_output(['git','ls-files','godot','tools','docs/validation'],cwd=root,text=True).splitlines()
files=[p for p in files if p.endswith(('.gd','.gdshader','.gdshaderinc','.py','.sh','.json','.godot','.tscn','.tres')) and '/evidence/' not in p]
def hashes():return {p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in files}
pins=hashes()
reference=json.loads((Path(__file__).resolve().parent/'source-sha256.json').read_text())
if pins!=reference: raise SystemExit('Source differs from frozen8334ce3a; use the exact source checkout.')
(out/'source-sha256.json').write_text(json.dumps(pins,indent=2)+'\n')
assets=root/'godot/demo/assets';backup=root.parent/'redwall-ug-full-8334-assets'
assert not backup.exists()
record={'head':head,'assets_present_before':assets.exists(),'commands':[]}
status=0
def run(cmd,log):
    t=time.monotonic()
    with (out/log).open('w') as f:r=subprocess.run(cmd,cwd=root,stdout=f,stderr=subprocess.STDOUT)
    record['commands'].append({'command':cmd,'exit_code':r.returncode,'seconds':round(time.monotonic()-t,3),'log':log})
    (out/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
    print(log,r.returncode,flush=True)
    for l in (out/log).read_text().splitlines():
        if l.startswith(('diagnostics:','log:','ok:','error:')) or ' test(s),' in l or 'GDScript warning(s)' in l:print(l,flush=True)
    if r.returncode:raise RuntimeError(log)
try:
    if assets.exists():assets.rename(backup)
    shutil.rmtree(root/'godot/.godot',ignore_errors=True)
    run(['godot','--headless','--path','godot','--editor','--quit'],'clean-import.log')
    run(['./tools/run_tests.sh'],'full-suite.log')
    run(['python3','tools/gdscript_warnings.py','--max','0','--port','6197','--json',str(out/'analyzer.json')],'analyzer.log')
except Exception as e:status=1;record['error']=str(e)
finally:
    if backup.exists():backup.rename(assets)
    record['assets_restored']=assets.exists()==record['assets_present_before']
    record['source_unchanged']=pins==hashes()
    record['head_unchanged']=head==subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    if not record['assets_restored'] or not record['source_unchanged'] or not record['head_unchanged']: status=1
    record['exit_code']=status
    (out/'invocation.json').write_text(json.dumps(record,indent=2)+'\n')
sys.exit(status)
