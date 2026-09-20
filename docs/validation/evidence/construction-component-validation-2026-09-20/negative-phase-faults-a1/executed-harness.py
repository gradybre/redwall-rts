from pathlib import Path
import json,subprocess,tempfile,shutil,re,hashlib,time
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/construction-component-validation-2026-09-20';out=e/'negative-phase-faults-a1';out.mkdir(exist_ok=False)
plan=json.loads((e/'negative-phase-fault-proposal.json').read_text());units=plan['cases'];assert len(units)==6
owner='godot/scripts/core/construction.gd';test='godot/test/test_construction_columns.gd';runner='godot/test/run_tests.gd';sources={n:(r/n).read_text() for n in [owner,test,runner]}
for u in units:
 for edit in u['edits']:assert sources[edit['path']].count(edit['old'])==1
needle='\t\tif not method_name.begins_with(TEST_PREFIX):';assert sources[runner].count(needle)==1
selection='\t\tif method_name != "test_negative_phase_relation_cases":\n\t\t\tcontinue\n'+needle
(out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n');shutil.copy2(__file__,out/'executed-harness.py');results=[];start=time.monotonic()
with tempfile.TemporaryDirectory(prefix='redwall-construction-negative-phase-') as tmp:
 c=Path(tmp);shutil.copytree(r/'godot',c/'godot');(c/'docs').symlink_to(r/'docs');(c/'assets').symlink_to(r/'assets');(c/runner).write_text(sources[runner].replace(needle,selection,1))
 (c/'godot/test/construction_negative_phase_focus.gd').write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_construction_columns.gd"])\n')
 for u in [None]+units+[None]:
  name=u['id'] if u else ('baseline-before' if not results else 'baseline-after');s=sources[owner]
  if u:
   for edit in u['edits']:assert edit['path']==owner and s.count(edit['old'])==1;s=s.replace(edit['old'],edit['new'],1)
  (c/owner).write_text(s);t=time.monotonic();p=subprocess.run(['godot','--headless','--path','godot','--script','test/construction_negative_phase_focus.gd'],cwd=c,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);log=p.stdout;(out/(name+'.log')).write_text(log)
  totals=re.findall(r'(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)',log);counts=list(map(int,totals[-1])) if totals else None;errors=[x for x in log.splitlines() if 'ERROR:' in x or 'Parse Error:' in x];failures=re.findall(r'^\s+FAIL\s+(test_\w+)',log,re.M)
  assertion_lines=[x.strip() for x in log.splitlines() if x.startswith('        ') and '(expected ' in x];expected_lines=[x+' (expected COLUMN_PHASE, got )' for x in u['target_test']['exact_assertion_labels']] if u else []
  valid=counts is not None and counts[:2]==[1,60] and not errors
  expected=valid and (p.returncode==1 and counts[2]==1 and failures==['test_negative_phase_relation_cases'] and sorted(assertion_lines)==sorted(expected_lines) if u else p.returncode==0 and counts[2]==0)
  rec={'case':name,'seconds':round(time.monotonic()-t,3),'exit_code':p.returncode,'counts':counts,'valid_execution':valid,'expected_outcome':bool(expected),'assertion_failures':assertion_lines,'expected_assertion_failures':expected_lines,'errors':errors,'mutated_sha256':hashlib.sha256(s.encode()).hexdigest(),'log_sha256':hashlib.sha256(log.encode()).hexdigest()};results.append(rec);print(json.dumps({k:rec[k] for k in ['case','counts','seconds','valid_execution','expected_outcome']}),flush=True)
  if not expected:print(log[-4000:],flush=True);break
record={'source_sha256':{n:hashlib.sha256(s.encode()).hexdigest() for n,s in sources.items()},'seconds':round(time.monotonic()-start,3),'results':results,'source_unchanged':all((r/n).read_text()==s for n,s in sources.items())};record['passed']=record['source_unchanged'] and len(results)==8 and all(x['expected_outcome'] for x in results);(out/'result.json').write_text(json.dumps(record,indent=2)+'\n');print('negative_phase_campaign_passed',record['passed']);raise SystemExit(0 if record['passed'] else 1)
