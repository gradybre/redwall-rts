from pathlib import Path
import json,subprocess,tempfile,shutil,re,hashlib,time
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/construction-component-validation-2026-09-20';out=e/'row-semantic-faults-a1';out.mkdir(exist_ok=False)
plan=json.loads((e/'row-allocation-fault-proposal.json').read_text());units=plan['cases'];assert len(units)==39
names=set(x['path'] for u in units for x in u['edits'])|set(x['path'] for u in units for x in u['targets']);names.add('godot/test/run_tests.gd');sources={n:(r/n).read_text() for n in names}
for u in units:
 for edit in u['edits']:assert sources[edit['path']].count(edit['old'])==1,(u['id'],edit['path'])
 for target in u['targets']:assert sources[target['path']].count('func '+target['function']+'(')==1
alltargets={(x['path'],x['function']) for u in units for x in u['targets']}
runner='godot/test/run_tests.gd';needle='\t\tif not method_name.begins_with(TEST_PREFIX):';assert sources[runner].count(needle)==1
(out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n');shutil.copy2(__file__,out/'executed-harness.py');results=[];start=time.monotonic()
with tempfile.TemporaryDirectory(prefix='redwall-construction-semantics-') as tmp:
 c=Path(tmp);shutil.copytree(r/'godot',c/'godot');(c/'docs').symlink_to(r/'docs',target_is_directory=True);(c/'assets').symlink_to(r/'assets',target_is_directory=True)
 for unit in [None]+units+[None]:
  name=unit['id'] if unit else ('baseline-before' if not results else 'baseline-after')
  targets={(x['path'],x['function']) for x in unit['targets']} if unit else alltargets
  suites=sorted({'res://'+p.removeprefix('godot/') for p,f in targets});methods=sorted({f for p,f in targets})
  for n in names:(c/n).write_text(sources[n])
  selection='\t\tif not method_name in '+json.dumps(methods)+':\n\t\t\tcontinue\n'+needle
  (c/runner).write_text(sources[runner].replace(needle,selection,1))
  (c/'godot/test/construction_semantic_fault_focus.gd').write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray('+json.dumps(suites)+')\n')
  mutated={}
  if unit:
   for edit in unit['edits']:
    n=edit['path'];s=mutated.get(n,sources[n]);assert s.count(edit['old'])==1;s=s.replace(edit['old'],edit['new'],1);mutated[n]=s;(c/n).write_text(s)
  t=time.monotonic();p=subprocess.run(['godot','--headless','--path','godot','--script','test/construction_semantic_fault_focus.gd'],cwd=c,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);log=p.stdout;(out/(name+'.log')).write_text(log)
  totals=re.findall(r'(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)',log);counts=list(map(int,totals[-1])) if totals else None
  errors=[line for line in log.splitlines() if 'ERROR:' in line or 'Parse Error:' in line];failures=re.findall(r'^\s+FAIL\s+(test_\w+)',log,re.M)
  valid=counts is not None and counts[0]==len(targets) and counts[1]>0 and not errors
  matching=[]
  if unit:
   for target in unit['targets']:
    pair='(expected %s, got %s)'%(target['baseline_expected'],target['mutant_expected'])
    if target['function'] in failures and pair in log:matching.append({'test':target['function'],'code_pair':pair})
  expected=valid and (p.returncode!=0 and counts[2]>0 and bool(matching) if unit else p.returncode==0 and counts[2]==0)
  rec={'case':name,'seconds':round(time.monotonic()-t,3),'exit_code':p.returncode,'selected_tests':sorted(targets),'counts':counts,'valid_execution':valid,'expected_outcome':bool(expected),'matching_evidence':matching,'failing_tests':failures,'errors':errors,'mutated_sha256':{n:hashlib.sha256(s.encode()).hexdigest() for n,s in mutated.items()},'log_sha256':hashlib.sha256(log.encode()).hexdigest()};results.append(rec);print(json.dumps({k:rec[k] for k in ['case','seconds','counts','valid_execution','expected_outcome']}),flush=True)
  if not expected:print(log[-5000:],flush=True);break
record={'source_sha256':{n:hashlib.sha256(s.encode()).hexdigest() for n,s in sources.items()},'proposal_source_sha256':plan['source_sha256'],'rebase':'Current owner adds exact stored-key preflight; tests add six phase witnesses. All39 exact mutations and every named target verified once. Selected original test bodies/framework unchanged; only deterministic method filter inserted in isolated runner.','seconds':round(time.monotonic()-start,3),'results':results,'source_unchanged':all((r/n).read_text()==s for n,s in sources.items())};record['passed']=record['source_unchanged'] and len(results)==len(units)+2 and all(x['expected_outcome'] for x in results);(out/'result.json').write_text(json.dumps(record,indent=2)+'\n');print('semantic_campaign_passed',record['passed']);raise SystemExit(0 if record['passed'] else 1)
