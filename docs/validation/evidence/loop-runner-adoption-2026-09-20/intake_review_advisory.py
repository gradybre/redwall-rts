import hashlib,json,sys,shutil
from pathlib import Path
w=Path(__file__).resolve().parent;r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19')
a,path,maxlines,maxwords=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4])
out=json.loads((w/(a+'.result.json')).read_text());inp=json.loads((w/(a+'.input.json')).read_text());assert out['state']=='complete' and out['ownerStopped'] and not out.get('quarantined',False) and not out.get('quarantine',False)
hashes={}
for f in inp.get('input',inp.get('files',[])):
 h=hashlib.sha256(f['content'].encode()).hexdigest();assert hashlib.sha256((r/f['path']).read_bytes()).hexdigest()==h,f['path'];hashes[f['path']]=h
files=out['result']['files'];assert len(files)==1;f=files[0];assert f['path']==path and f.get('baseSha256') is None and not (r/path).exists();s=f['content'];lines=len(s.splitlines());words=len(s.split());assert len(s.encode())<=8*1024*1024; length_target_exceeded=lines>maxlines or words>maxwords
p=r/path;p.write_text(s)
for suffix in ['packet.json','spec.json','input.json','provider.json','context.json','result.json','delivery-check.json','events.jsonl']:
 if (w/(a+'.'+suffix)).exists():shutil.copy2(w/(a+'.'+suffix),p.parent/(a+'.'+suffix))
ledger=p.parent/'worker-ledger.json';j=json.loads(ledger.read_text()) if ledger.exists() else {'attempts':[]};j['attempts'].append(dict(id=a,model=out['model'],sessionId=out.get('sessionId'),state=out['state'],ownerStopped=out['ownerStopped'],inputHashes=hashes,outputLines=lines,outputWords=words,outputLineBudget=maxlines,outputWordBudget=maxwords,length_targets_advisory=True,length_target_exceeded=length_target_exceeded,full_text_preserved=True));ledger.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(path=path,lines=lines,words=words,length_target_exceeded=length_target_exceeded,full_text_preserved=True)))
