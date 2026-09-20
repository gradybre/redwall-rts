from pathlib import Path
import json,subprocess,tempfile,shutil,re,ast,hashlib,time,sys
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/construction-component-validation-2026-09-20';label=sys.argv[1];assert re.fullmatch('[a-z0-9-]+',label);out=e/label;out.mkdir(exist_ok=False);plan=json.loads((e/'metadata-scalar-fault-plan-v2.json').read_text());owner='godot/scripts/core/construction.gd';paths=sorted({x['path'] for x in plan['cases']});originals={p:(r/p).read_text() for p in paths};probe=e/'metadata-owner-probe.gd';results=[];start=time.monotonic()
def mutate(s,case):
 if case['kind']=='scalar':
  pat=r'(^const '+re.escape(case['name'])+r': [^=\n]+ = )([^\n]+)';matches=list(re.finditer(pat,s,re.M));assert len(matches)==1;found=matches[0];assert found[2]==case['frozen_original_expression'];return s[:found.start(2)]+case['new_expression']+s[found.end(2):]
 if case['kind']=='dictionary-field-type':
  pat=r'(const '+case['name']+r': Dictionary = )(\{.*?\})';m=re.search(pat,s,re.S);assert m;v=ast.literal_eval(m[2]);v[list(v)[-1]][0]='wrong-type';return s[:m.start(2)]+json.dumps(v)+s[m.end(2):]
 pat=r'(const '+re.escape(case['name'])+r': Array\[\w+\] = )(\[[^\]]*\])';m=re.search(pat,s,re.S);assert m;raw=m[2];v=ast.literal_eval(raw.replace('&"','"'));op=case['operation']
 if op=='short':v.pop()
 elif op=='long':v.append(v[-1])
 elif op=='swap-first-two':v[0],v[1]=v[1],v[0]
 else:raise AssertionError(op)
 rendered=json.dumps(v)
 if 'Array[StringName]' in m[1]:rendered=re.sub(r'"([^"\\]*)"',r'&"\1"',rendered)
 return s[:m.start(2)]+rendered+s[m.end(2):]
def execute(c,name,fault,expect_counterfactual=False):
 t=time.monotonic();args=['godot','--headless','--path','godot','--script','test/construction_metadata_scalar_probe.gd']+(['--','--fault'] if fault else []);p=subprocess.run(args,cwd=c,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60);(out/(name+'.log')).write_text(p.stdout);m=re.search(r'^checks=(\d+) mismatches=(\d+) ok=(true|false)$',p.stdout,re.M);valid=m is not None and int(m[1])==5 and not re.search('SCRIPT ERROR:|Parse Error:|ERROR:',p.stdout);passed=bool(valid and p.returncode==0 and int(m[2])==0 and m[3]=='true');caught=bool(valid and p.returncode!=0 and int(m[2])>0 and m[3]=='false');record=dict(case=name,exit_code=p.returncode,seconds=round(time.monotonic()-t,3),checks=int(m[1]) if m else None,mismatches=int(m[2]) if m else None,valid_execution=bool(valid),passed=passed,counterfactual_caught=caught if expect_counterfactual else None,log_sha256=hashlib.sha256(p.stdout.encode()).hexdigest());results.append(record);
 if not (passed or caught): print(json.dumps(record),flush=True)
 if not (caught if expect_counterfactual else passed):print(p.stdout[-2200:],flush=True)
 return caught if expect_counterfactual else passed
try:
 with tempfile.TemporaryDirectory(prefix='redwall-construction-metadata-scalar-') as tmp:
  c=Path(tmp);shutil.copytree(r/'godot',c/'godot');(c/'docs').symlink_to(r/'docs',target_is_directory=True);(c/'assets').symlink_to(r/'assets',target_is_directory=True);project=c/'godot/project.godot';s,n=re.subn(r'(?ms)^\[autoload\]\n.*?(?=^\[|\Z)','',project.read_text());assert n==1;project.write_text(s);shutil.copy2(probe,c/'godot/test/construction_metadata_scalar_probe.gd')
  assert execute(c,'baseline-before',False)
  for case in plan['cases']:
   target=c/case['path'];target.write_text(mutate(originals[case['path']],case));execute(c,case['id'],True);target.write_text(originals[case['path']])
  case=next(x for x in plan['cases'] if x['name']=='MAX_BUILDERS');s=mutate(originals[owner],case);needle='\tvar scalar_code: StringName = _source_scalar_refusal()\n\tif scalar_code != REFUSE_NONE:\n\t\treturn scalar_code\n';assert s.count(needle)==1;(c/owner).write_text(s.replace(needle,''));execute(c,'counterfactual-scalar-guard-bypass',True,True);(c/owner).write_text(originals[owner]);assert execute(c,'baseline-after',False)
finally:
 record=dict(scope='Owner scalar/extent preflight correction only; not complete Construction or bridge acceptance',source_sha256={p:hashlib.sha256(v.encode()).hexdigest() for p,v in originals.items()},probe_sha256=hashlib.sha256(probe.read_bytes()).hexdigest(),elapsed_seconds=round(time.monotonic()-start,3),results=results,source_unchanged=all((r/p).read_text()==s for p,s in originals.items()));(out/'result.json').write_text(json.dumps(record,indent=2)+'\n')
passed=len(results)==48 and all(x['passed'] or x['counterfactual_caught'] for x in results) and record['source_unchanged'];print(json.dumps({'total_cases':len(results),'valid':sum(x['valid_execution'] for x in results),'passed_all':passed,'result':str(out/'result.json')}));sys.exit(0 if passed else 1)
