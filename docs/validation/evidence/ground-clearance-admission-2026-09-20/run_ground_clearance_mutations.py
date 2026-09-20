"""Three scoped semantic counterfactuals; script/engine failure is never a caught mutant."""
from pathlib import Path
import json,tempfile,shutil,subprocess,hashlib,time,re,sys
R=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');E=R/'docs/validation/evidence/ground-clearance-admission-2026-09-20'
control=json.loads((E/(sys.argv[1]+'.json')).read_text());assert control['passed'] and control['kind']=='focus';assert not (E/'mutation-results.json').exists()
for path,h in control['source_sha256'].items():assert hashlib.sha256((R/path).read_bytes()).hexdigest()==h
mutants=[('qualification-bypass','scripts/core/movement.gd','\tif not profile_clearance_class_into(admission.profile_id, _scratch):\n\t\treturn StringName(_scratch.error)','\tif not profile_clearance_class_into(admission.profile_id, _scratch):\n\t\treturn REFUSE_NONE'),('mismatch-bypass','scripts/core/movement.gd','\tif _scratch.value != profile_class:\n\t\treturn REFUSE_ROUTE_CLEARANCE','\tif _scratch.value != profile_class:\n\t\treturn REFUSE_NONE'),('getter-fixed-class-one','scripts/core/navigation.gd','return out.succeed(_d_clearance[_r_route_id[row]])','return out.succeed(1)')]
results=[]
with tempfile.TemporaryDirectory(prefix='redwall-clearance-mutations-') as tmp:
 root=Path(tmp);shutil.copytree(R/'godot',root/'godot');(root/'docs').symlink_to(R/'docs',target_is_directory=True);(root/'assets').symlink_to(R/'assets',target_is_directory=True)
 for label,path,old,new in mutants:
  p=root/'godot'/path;s=p.read_text();assert s.count(old)==1,(label,s.count(old));mutated=s.replace(old,new,1);p.write_text(mutated);start=time.monotonic();timeout=False
  try:
   run=subprocess.run(['godot','--headless','--path','godot','--script','res://test/ground_clearance_focus.gd'],cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);output=run.stdout;code=run.returncode
  except subprocess.TimeoutExpired as ex:
   output=ex.stdout or '';output=output.decode() if isinstance(output,bytes) else output;code=None;timeout=True
  finally:p.write_text(s)
  log=E/('mutant-'+label+'.log');assert not log.exists();log.write_text(output);counts=re.findall(r'(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)',output);counts=list(map(int,counts[-1])) if counts else None;errors=bool(re.search('SCRIPT ERROR:|Parse Error:|ERROR:',output));caught=code==1 and not timeout and not errors and counts is not None and counts[0]==control['counts'][0] and counts[2]>0;item={'id':label,'path':path,'old':old,'new':new,'source_sha256':hashlib.sha256(s.encode()).hexdigest(),'mutant_sha256':hashlib.sha256(mutated.encode()).hexdigest(),'seconds':round(time.monotonic()-start,3),'exit_code':code,'timed_out':timeout,'counts':counts,'script_or_engine_error':errors,'caught':caught,'failed_tests':[x.strip() for x in output.splitlines() if x.startswith('  FAIL')],'log':log.name,'log_sha256':hashlib.sha256(output.encode()).hexdigest()};results.append(item);print(json.dumps(item),flush=True)
for path,h in control['source_sha256'].items():assert hashlib.sha256((R/path).read_bytes()).hexdigest()==h
record={'control':sys.argv[1]+'.json','source_sha256':control['source_sha256'],'mutants':results,'caught':sum(x['caught'] for x in results),'total':len(results),'passed':all(x['caught'] for x in results),'source_unchanged':True,'scope':'Three declared admission counterfactuals; not exhaustive mutation coverage or native-memory qualification'};(E/'mutation-results.json').write_text(json.dumps(record,indent=2)+'\n');sys.exit(0 if record['passed'] else 1)
