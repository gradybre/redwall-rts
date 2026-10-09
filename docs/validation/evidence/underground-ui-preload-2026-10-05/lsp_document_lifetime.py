#!/usr/bin/env python3
"""Evidence-only comparison of document lifetime; production analyzer remains unchanged."""
import argparse,hashlib,importlib.util,json,os,re,shutil,subprocess,time
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[4]
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True);ap.add_argument('--scope',choices=['ui','all'],default='ui');ap.add_argument('--retain',action='store_true');ap.add_argument('--port',type=int,default=6470);ap.add_argument('--clean',action='store_true');a=ap.parse_args()
    a.out.mkdir(parents=True,exist_ok=False)
    (a.out/'procedure.py.txt').write_bytes(Path(__file__).read_bytes())
    if a.clean:
        assert not (ROOT/'godot/demo/assets').exists(), 'this own checkout has no staged assets'
        shutil.rmtree(ROOT/'godot/.godot',ignore_errors=True)
        with (a.out/'clean-import.log').open('w') as stream:
            r=subprocess.run(['godot','--headless','--path','godot','--editor','--quit'],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        if r.returncode or re.search(r'^\s*(?:SCRIPT ERROR|ERROR|WARNING):', (a.out/'clean-import.log').read_text(),re.M):return 2
    spec=importlib.util.spec_from_file_location('unchanged_analyzer',ROOT/'tools/gdscript_warnings.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    paths=mod.gd_files(ROOT/'godot', [] if a.scope=='all' else [str(ROOT/'godot/scripts/ui')])
    pins={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    log=Path(os.environ.get('TMPDIR','/tmp'))/f'gdscript_warnings_editor_{a.port}.log'
    trace=[]
    class InspectLsp(mod.Lsp):
        def send(self,message):
            if message.get('method','').startswith('textDocument/'):
                trace.append({'method':message['method'],'uri':message['params']['textDocument']['uri'],'editor_bytes':log.stat().st_size})
                if message['method']=='textDocument/didClose' and a.retain:return None
            return super().send(message)
    mod.Lsp=InspectLsp
    started=time.monotonic()
    found=mod.collect_all(SimpleNamespace(port=a.port,godot='godot'),paths,ROOT/'godot',ROOT/'godot')
    raw=log.read_text();(a.out/'editor.log').write_text(raw)
    errors=re.findall(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):.*$',raw,re.M)
    result={'files':len(paths),'source_sha256':pins,'retain_documents':a.retain,'scope':a.scope,'diagnostics':found,'raw_errors':errors,'seconds':round(time.monotonic()-started,3),'source_unchanged':pins=={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
    (a.out/'result.json').write_text(json.dumps(result,indent=2)+'\n');(a.out/'trace.json').write_text(json.dumps(trace,indent=2)+'\n')
    print({k:v for k,v in result.items() if k!='source_sha256'},flush=True)
    return 1 if found or errors or not result['source_unchanged'] else 0
if __name__=='__main__':raise SystemExit(main())
