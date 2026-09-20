#!/usr/bin/env python3
"""Execute60 actual Construction source/schema faults with unchanged-source controls."""
from pathlib import Path
import json,tempfile,shutil,subprocess,re,hashlib,time,argparse

def main():
    if not __debug__:raise SystemExit("Construction evidence requires Python assertions enabled; optimized mode is unsupported")
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir',type=Path,help='Retain detailed per-case evidence in a new directory')
    args=parser.parse_args()
    if args.output_dir is not None:args.output_dir.mkdir(parents=True,exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="redwall-construction-metadata-logs-") as output_dir:
        r=Path(__file__).resolve().parents[1];e=r/'docs/validation/evidence/construction-component-validation-2026-09-20';out=args.output_dir if args.output_dir is not None else Path(output_dir);plan=json.loads((e/'bridge-metadata-fault-proposal.json').read_text());followup=json.loads((e/'review-followup-fault-proposal.json').read_text());assert len(plan['cases'])==55 and len(followup['cases'])==5;cases=plan['cases']+followup['cases'];assert len({case['id'] for case in cases})==60;paths=sorted({a['path'] for case in cases for a in case['edits']}|{'godot/scripts/core/save_owner_construction.gd'});originals={n:(r/n).read_text() for n in paths};hashes={n:hashlib.sha256(s.encode()).hexdigest() for n,s in originals.items()};changed={n:dict(proposed=plan['source_sha256'][n],executed=h) for n,h in hashes.items() if h!=plan['source_sha256'][n]}
        for name in paths:
            path=Path(name);assert not path.is_absolute() and ".." not in path.parts and path.parts[:3]==("godot","scripts","core") and path.suffix==".gd", "Fault path outside isolated core source"
        for case in cases:
         for edit in case['edits']:assert originals[edit['path']].count(edit['old'])==1,(case['id'],edit['path'])
        record=dict(scope='60 source/schema/independent bridge-anchor fault units, no whole-save claim',source_sha256=hashes,proposal_rebase=changed,rebase_rationale='Historical proposal hashes retained; actual current hashes recorded and all60 exact edits verified once before execution.',observer_sha256=hashlib.sha256((e/'metadata-bridge-observer.gd').read_bytes()).hexdigest(),results=[]);start=time.monotonic()
        with tempfile.TemporaryDirectory(prefix='redwall-construction-bridge-metadata-') as tmp:
         c=Path(tmp);shutil.copytree(r/'godot',c/'godot');(c/'docs').symlink_to(r/'docs');(c/'assets').symlink_to(r/'assets');project=c/'godot/project.godot';s,n=re.subn(r'(?ms)^\[autoload\]\n.*?(?=^\[|\Z)','',project.read_text());assert n==1;project.write_text(s);shutil.copy2(e/'metadata-bridge-observer.gd',c/'godot/test/construction_metadata_bridge_probe.gd')
         for i,case in enumerate([None,*cases,None]):
          name=('baseline-before' if i==0 else 'baseline-after') if case is None else case['id'];expected=case['expected'] if case else dict(pure_source_code='',bridge_code='SAVE_COMPONENT_SHAPE',bridge_detail_prefix='',first_gate='5/shape')
          if case:
           for edit in case['edits']:
            target=c/edit['path'];s=target.read_text();assert s.count(edit['old'])==1;target.write_text(s.replace(edit['old'],edit['new'],1))
          t=time.monotonic();p=subprocess.run(['godot','--headless','--path','godot','--script','test/construction_metadata_bridge_probe.gd']+(['--','--fault'] if expected['pure_source_code'] else []),cwd=c,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60);log=p.stdout;(out/(name+'.log')).write_text(log);m=re.search(r'^checks=(\d+) mismatches=(\d+) ok=(true|false)$',log,re.M);obs=re.findall(r'^CONSTRUCTION_BRIDGE_OBSERVATION (.*)$',log,re.M);data=json.loads(obs[0]) if len(obs)==1 else {};valid=bool(m and int(m[1])==5 and data and not re.search(r'SCRIPT ERROR:|Parse Error:|ERROR:',log));pure_ok=bool(valid and p.returncode==0 and int(m[2])==0 and m[3]=='true');forward=expected['first_gate'].startswith('3/');bridge_ok=bool(valid and data['code']==expected['bridge_code'] and data['detail'].startswith(expected['bridge_detail_prefix']));forward_ok=not forward or (data.get('code')==data.get('schema_code') and data.get('detail')==data.get('schema_detail'));early_ok=bool(data and data['null_code']=='SAVE_COMPONENT_SHAPE' and data['wrong_owner_code']=='SAVE_COMPONENT_OWNER');passed=pure_ok and bridge_ok and forward_ok and early_ok;result=dict(case=name,exit_code=p.returncode,valid_execution=valid,pure_checks=int(m[1]) if m else None,pure_mismatches=int(m[2]) if m else None,bridge=data,expected=expected,forward_exact=forward_ok,early_priority=early_ok,passed=passed,seconds=round(time.monotonic()-t,3));record['results'].append(result)
          if not passed:print(json.dumps(result),flush=True)
          for n,s in originals.items():(c/n).write_text(s)
        record.update(seconds=round(time.monotonic()-start,3),source_unchanged=all((r/n).read_text()==s for n,s in originals.items()));(out/'result.json').write_text(json.dumps(record,indent=2)+'\n');shutil.copy2(__file__,out/'executed-harness.py');print(json.dumps(dict(runs=len(record['results']),fault_units=60,valid=sum(x['valid_execution'] for x in record['results']),passed=sum(x['passed'] for x in record['results']),source_unchanged=record['source_unchanged'],seconds=record['seconds'])),flush=True)
        assert record['source_unchanged'] and len(record['results'])==62 and all(x['passed'] for x in record['results']), 'Construction source/schema fault evidence failed'

if __name__=="__main__":main()
