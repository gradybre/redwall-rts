"""Astra-invoked intake only; worker completion itself never applies files."""
from pathlib import Path
import sys,json,hashlib,shutil,subprocess
w=Path(__file__).resolve().parent;r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19').resolve();attempt,evidence=sys.argv[1:];assert '/' not in attempt and '..' not in attempt
p=json.loads((w/(attempt+'.packet.json')).read_text());i=json.loads((w/(attempt+'.input.json')).read_text());o=json.loads((w/(attempt+'.result.json')).read_text());d=json.loads((w/(attempt+'.delivery-check.json')).read_text())
assert i['root']==str(r) and i['scope']==p['scope']==d['scope'];assert p['scope']['project']=='redwall-rts';assert o['model']==p['scope']['model'];assert o['state']=='complete' and o['ownerStopped'] and not o.get('quarantine') and not o.get('quarantined');assert not o['result']['questions']
def h(b):return hashlib.sha256(b).hexdigest()
def target(name):
 q=Path(name);assert not q.is_absolute() and not any(x in ['..','.git'] for x in q.parts);out=(r/q).resolve();assert out.is_relative_to(r);return out
for f in i['files']:
 assert f['sha256']==h(f['content'].encode());assert h(target(f['path']).read_bytes())==f['sha256'],f['path']
files=o['result']['files'];assert len(files)==len(p['allowedWrites']) and {x['path'] for x in files}==set(p['allowedWrites']);assert set(d['returnedPaths'])==set(p['allowedWrites']);assert d['approval']=='not_granted' and not d['sourceApplied']
for f in files:
 q=target(f['path']);actual=h(q.read_bytes()) if q.exists() else None;assert actual==f['baseSha256']==p['allowedWrites'][f['path']];assert len(f['content'].encode())<=8*1024*1024
for f in files:
 q=target(f['path']);q.parent.mkdir(parents=True,exist_ok=True);q.write_text(f['content'])
e=target(evidence);e.mkdir(parents=True,exist_ok=True)
for suffix in ['packet.json','spec.json','input.json','provider.json','context.json','result.json','delivery-check.json','events.jsonl']:
 source=w/(attempt+'.'+suffix)
 if source.exists():shutil.copy2(source,e/source.name)
record=dict(attempt=attempt,scope=p['scope'],session_id=o['sessionId'],owner_stopped=True,base_commit=p['base_commit'],integration_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),source_inputs_reverified=True,files={f['path']:h(f['content'].encode()) for f in files},approval='artifact_intake_only_not_product_acceptance')
(e/(attempt+'.intake.json')).write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
