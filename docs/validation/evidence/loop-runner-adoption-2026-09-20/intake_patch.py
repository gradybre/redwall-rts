import hashlib,json,sys,shutil,subprocess
from pathlib import Path
w=Path(__file__).resolve().parent;r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19')
a,path,maxlines,*targets=sys.argv[1:];maxlines=int(maxlines);allowed=set(targets)
out=json.loads((w/(a+'.result.json')).read_text());inp=json.loads((w/(a+'.input.json')).read_text());assert out['state']=='complete' and out['ownerStopped'] and not out.get('quarantine',False) and not out.get('quarantined',False)
hashes={}
for f in inp.get('input',inp.get('files',[])):
 h=hashlib.sha256(f['content'].encode()).hexdigest();assert hashlib.sha256((r/f['path']).read_bytes()).hexdigest()==h,f['path'];hashes[f['path']]=h
files=out['result']['files'];assert len(files)==1;f=files[0];assert f['path']==path and f.get('baseSha256') is None and not (r/path).exists();s=f['content'];lines=len(s.splitlines());assert lines<=maxlines,lines
seen=set()
for line in s.splitlines():
 if line.startswith(('+++ ','--- ')):
  p=line[4:];assert p=='/dev/null' or (p[:2] in ['a/','b/'] and p[2:] in allowed),p
  if p!='/dev/null':seen.add(p[2:])
 if line.startswith('diff --git '):
  parts=line.split();assert len(parts)==4 and parts[2][2:] in allowed and parts[3][2:] in allowed and parts[2][2:]==parts[3][2:]
 assert not line.startswith(('rename ','old mode','new mode','GIT binary','Binary files','deleted file mode'))
 if line.startswith('new file mode'):assert line=='new file mode 100644'
assert seen==allowed,(seen,allowed)
p=r/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
subprocess.run(['git','apply','--recount','--check',str(p)],cwd=r,check=True)
subprocess.run(['git','apply','--recount',str(p)],cwd=r,check=True)
for suffix in ['packet.json','spec.json','input.json','provider.json','context.json','result.json','delivery-check.json','events.jsonl']:
 if (w/(a+'.'+suffix)).exists():shutil.copy2(w/(a+'.'+suffix),p.parent/(a+'.'+suffix))
ledger=p.parent/'worker-ledger.json';j=json.loads(ledger.read_text()) if ledger.exists() else {'attempts':[]};j['attempts'].append(dict(id=a,model=out['model'],sessionId=out.get('sessionId'),state=out['state'],ownerStopped=out['ownerStopped'],inputHashes=hashes,outputLines=lines,outputLineBudget=maxlines,applied='git apply --recount --check then --recount; frozen inputs and target/mode allowlist verified',integration_base=subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip()));ledger.write_text(json.dumps(j,indent=2)+'\n');print('Applied verified patch:',lines,'lines')
