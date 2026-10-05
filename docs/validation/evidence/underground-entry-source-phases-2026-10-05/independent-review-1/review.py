#!/usr/bin/env python3
"""Independent narrow 1189 source/data review. Writes only beside this script; never runs Godot."""
import hashlib, importlib.util, json, re, subprocess, sys
from pathlib import Path
ROOT=Path('/Users/brendan/Developer/redwall-rts-codex-ug-integration')
E=Path(__file__).resolve().parent
BASE='godot/data/underground/first-entry-prefix-v1/'
PATHS=[BASE+'rebind_handling_diagnostic.py',BASE+'test_rebind_handling_diagnostic.py',
       BASE+'compile_entry_prefix.py',BASE+'compile_entry_frontier.py',
       'godot/scripts/core/underground_entry_world_bindings.gd',
       'docs/validation/evidence/underground-entry-source-phases-2026-10-05/focus-5/test_underground_entry_source_phases.gd.txt']
def sha(raw): return hashlib.sha256(raw).hexdigest()
def frames(text):
    matches=list(re.finditer(r'^(?:static )?func (\w+)\(',text,re.M)); out={}
    widths={'int':8,'bool':1,'Vector2i':8,'Vector3i':12}
    for i,m in enumerate(matches):
        s=text[m.start():matches[i+1].start() if i+1<len(matches) else len(text)]
        s=re.sub(r'""".*?"""','',s,flags=re.S)
        signature,code=s.split('->',1); code=code.split('\n',1)[1]
        fields=re.findall(r'(\w+)\s*:\s*(int|bool|Vector2i|Vector3i)\b',signature)
        fields+=re.findall(r'\b(?:var|for)\s+(\w+)\s*:\s*(int|bool|Vector2i|Vector3i)\b',code)
        out[m[1]]={'numeric_fields':fields,'numeric_bytes':sum(widths[t] for _,t in fields),
                   'calls':sorted(set(re.findall(r'(?<![\w.])([A-Za-z_]\w*)\s*\(',code)))}
    def chain(name,stack=()):
        assert name not in stack
        children=[chain(k,stack+(name,)) for k in out[name]['calls'] if k in out]
        child=max(children,key=lambda p:p[0]) if children else (0,[])
        return out[name]['numeric_bytes']+child[0],[name]+child[1]
    return out,max((chain(n) for n in out),key=lambda p:p[0])
def main():
    before={p:sha((ROOT/p).read_bytes()) for p in PATHS}
    module='godot/scripts/core/underground_entry_world_bindings.gd'
    now=(ROOT/module).read_text()
    frozen=(ROOT/'docs/validation/evidence/underground-entry-source-phases-2026-10-05/focus-5/underground_entry_world_bindings.gd.txt').read_text()
    assert now==frozen
    old=subprocess.check_output(['git','show','HEAD:'+module],cwd=ROOT).decode()
    rows=lambda text: re.findall(r'^var .*$',text,re.M)
    allocations=lambda text: re.findall(r'\bPacked\w+Array\(|\.(?:new|resize|duplicate)\(',text)
    assert rows(now)==rows(old) and allocations(now)==allocations(old)
    old_frames,old_chain=frames(old); new_frames,new_chain=frames(now)
    assert set(new_frames)-set(old_frames)=={'_entry_has_air_contact'}
    assert new_frames['_entry_has_air_contact']['numeric_bytes']==8
    for name in old_frames:
        assert old_frames[name]['numeric_fields']==new_frames[name]['numeric_fields'],name
    assert len(re.findall(r'if _entry_has_air_contact\(actual, (?:role|actual\._box\.role)\)',now))==3
    spec=importlib.util.spec_from_file_location('independent_diagnostic',ROOT/PATHS[0])
    d=importlib.util.module_from_spec(spec); spec.loader.exec_module(d)
    bundle=ROOT/'docs/validation/evidence/underground-entry-source-phases-2026-10-05/handling-diagnostic-1'
    rebuilt=d.build((bundle/'mole-worker.ugprof').read_bytes())
    for name,raw in rebuilt.items(): assert raw==(bundle/name).read_bytes(),name
    manifest=json.loads(rebuilt['manifest.json'])
    for p,pin in manifest['inputs'].items(): assert sha((ROOT/p).read_bytes())==pin,p
    with (E/'python-tests.log').open('w') as log:
        result=subprocess.run([sys.executable,'-B',str(ROOT/PATHS[1])],cwd=E,stdout=log,stderr=subprocess.STDOUT)
    assert result.returncode==0
    after={p:sha((ROOT/p).read_bytes()) for p in PATHS}; assert before==after
    report={'source_sha256':before,'source_unchanged':True,'diagnostic_outputs':{k:sha(v) for k,v in rebuilt.items()},
            'diagnostic_tests':6,'entry_world':{'retained_delta':0,'allocation_delta':0,'new_helper_numeric_bytes':8,
            'new_helper':new_frames['_entry_has_air_contact'],'old_own_chain':old_chain,'new_own_chain':new_chain,
            'existing_fixed':202,'existing_helper':1024,'reservation':2048,
            'scope':'Own numeric frame delta; foreign Contacts/phase caller ceilings retain their separately reviewed charge.'},
            'verdict':'ACCEPTED narrow source/diagnostic scope; no production handling, World or native-memory qualification',
            'reason':'Every source volume is retained; only positive-Y approach-role primitives emit additional air contacts. Unsupported complete negative and mixed BODY regressions still refuse before payment. Exact diagnostic content4 rebind preserves predecessor geometry, bills, and source selectors.'}
    (E/'review.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report['entry_world'],indent=2))
if __name__=='__main__': main()
