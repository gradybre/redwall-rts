from pathlib import Path
import json,tempfile,shutil,subprocess,re,hashlib,time
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/construction-component-validation-2026-09-20';out=e/'dictionary-key-types-a1';out.mkdir(exist_ok=False);p=json.loads((e/'bridge-metadata-fault-proposal.json').read_text());cases=[c for c in p['cases'] if c['id'].endswith('actual-key-stringname')];assert len(cases)==4
originals={a['path']:(r/a['path']).read_text() for c in cases for a in c['edits']};results=[]
for name,s in originals.items():assert hashlib.sha256(s.encode()).hexdigest()==p['source_sha256'][name]
with tempfile.TemporaryDirectory(prefix='redwall-construction-key-types-') as tmp:
 c=Path(tmp);shutil.copytree(r/'godot',c/'godot');(c/'docs').symlink_to(r/'docs');(c/'assets').symlink_to(r/'assets');project=c/'godot/project.godot';s,n=re.subn(r'(?ms)^\[autoload\]\n.*?(?=^\[|\Z)','',project.read_text());assert n==1;project.write_text(s);shutil.copy2(e/'metadata-owner-probe.gd',c/'godot/test/construction_metadata_scalar_probe.gd')
 for case in [None,*cases,None]:
  name=('baseline-before' if not results else 'baseline-after') if case is None else case['id']
  if case:
   for edit in case['edits']:
    target=c/edit['path'];s=target.read_text();assert s.count(edit['old'])==1;target.write_text(s.replace(edit['old'],edit['new']))
  t=time.monotonic();proc=subprocess.run(['godot','--headless','--path','godot','--script','test/construction_metadata_scalar_probe.gd']+(['--','--fault'] if case else []),cwd=c,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60);(out/(name+'.log')).write_text(proc.stdout);m=re.search(r'^checks=(\d+) mismatches=(\d+) ok=(true|false)$',proc.stdout,re.M);valid=bool(m and int(m[1])==5 and not re.search('SCRIPT ERROR:|Parse Error:|ERROR:',proc.stdout));results.append(dict(case=name,valid_execution=valid,exit_code=proc.returncode,checks=int(m[1]) if m else None,mismatches=int(m[2]) if m else None,required_expectations_met=valid and proc.returncode==0,seconds=round(time.monotonic()-t,3)));print(json.dumps(results[-1]),flush=True)
  for name,s in originals.items():(c/name).write_text(s)
record=dict(scope='Four required TYPE_STRING key refusals through existing independent owner probe; bridge not executed',source_unchanged=all((r/n).read_text()==s for n,s in originals.items()),source_sha256={n:hashlib.sha256(s.encode()).hexdigest() for n,s in originals.items()},probe_sha256=hashlib.sha256((e/'metadata-owner-probe.gd').read_bytes()).hexdigest(),results=results);(out/'result.json').write_text(json.dumps(record,indent=2)+'\n');shutil.copy2(__file__,out/'executed-harness.py')
