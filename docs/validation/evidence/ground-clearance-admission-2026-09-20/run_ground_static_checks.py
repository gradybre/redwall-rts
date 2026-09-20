from pathlib import Path
import json,subprocess,time,sys
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/ground-clearance-admission-2026-09-20';out=e/(sys.argv[1]+'.json');assert not out.exists()
prior=json.loads((r/'docs/validation/evidence/starter-integration-planning-2026-09-20/final-packaging-static-checks.json').read_text());records=[]
for item in prior:
 command=item['command'];start=time.monotonic();p=subprocess.run(command,cwd=r,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);records.append({'command':command,'exit_code':p.returncode,'seconds':round(time.monotonic()-start,3),'output':p.stdout});print(command[-1],p.returncode,flush=True)
 if p.returncode:break
out.write_text(json.dumps(records,indent=2)+'\n');sys.exit(0 if len(records)==len(prior) and all(x['exit_code']==0 for x in records) else 1)
