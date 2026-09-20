from pathlib import Path
import json,subprocess,tempfile,shutil,re,hashlib,time
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/construction-component-validation-2026-09-20';out=e/'projection-purity-faults-a1';out.mkdir(exist_ok=False)
bridge='godot/scripts/core/save_owner_construction.gd';owner='godot/scripts/core/construction.gd';test='godot/test/test_save_owner_construction.gd';sources={n:(r/n).read_text() for n in [bridge,owner,test]};source=sources[bridge];lines=re.findall(r'^\tout\.(\w+) = record\.(u8|i32|i64)_column\((FIELD_\w+)\)$',source,re.M);assert len(lines)==16
units=[]
for name,kind,field in lines:
 old=f'\tout.{name} = record.{kind}_column({field})';units.append({'id':'omit-'+name,'path':bridge,'replacements':[[old,'\t# Actual mapping assignment omitted by controlled fault.']],'expected_test':'test_direct_project_columns_matches_distinguishable_patterns'})
swaps=[('present','paused'),('paused','work_begun'),('present','work_begun'),('material_container_slot','material_container_generation'),('assigned_count','max_workers'),('refund_policy','phase'),('ref_slot','subject_slot'),('ref_generation','subject_generation'),('purpose','type_id')]
byname={x[0]:x for x in lines}
for a,b in swaps:
 _,kind,fa=byname[a];_,other,fb=byname[b];assert kind==other
 olda=f'\tout.{a} = record.{kind}_column({fa})';oldb=f'\tout.{b} = record.{kind}_column({fb})'
 units.append({'id':'swap-'+a+'-'+b,'path':bridge,'replacements':[[olda,f'\tout.{a} = record.{kind}_column({fb})'],[oldb,f'\tout.{b} = record.{kind}_column({fa})']],'expected_test':'test_direct_project_columns_matches_distinguishable_patterns'})
needle='\tvar source_code: StringName = column_source_metadata_refusal()';assert sources[owner].count(needle)==1
write='\timage.max_workers[82943] = 4\n\timage.refund_policy[82943] = 1\n\timage.type_id[82943] = 19\n\timage.phase[82943] = 3\n'+needle
units.append({'id':'direct-predicate-writes-valid-retired-row','path':owner,'replacements':[[needle,write]],'expected_test':'test_direct_columns_full_equality_after_success','rationale':'Turns final clear row into a locally valid retired BUILD/DONE row; success code stays NONE, caller-owned bytes change.'})
(out/'plan.json').write_text(json.dumps({'units':units,'scope':'16 actual mapper omissions,9 same-type swaps covering all multi-field type members,1 direct valid-row write; no exhaustive arbitrary fault claim'},indent=2)+'\n');results=[];start=time.monotonic();expected_tests=len(re.findall(r'^func test_',sources[test],re.M))
with tempfile.TemporaryDirectory(prefix='redwall-construction-projection-') as tmp:
 c=Path(tmp);shutil.copytree(r/'godot',c/'godot');(c/'docs').symlink_to(r/'docs',target_is_directory=True);(c/'assets').symlink_to(r/'assets',target_is_directory=True)
 (c/'godot/test/construction_projection_fault_focus.gd').write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_save_owner_construction.gd"])\n')
 for unit in [None]+units+[None]:
  name=unit['id'] if unit else ('baseline-before' if not results else 'baseline-after')
  for n in [bridge,owner]:(c/n).write_text(sources[n])
  changed=None
  if unit:
   changed=sources[unit['path']]
   for old,new in unit['replacements']:
    assert changed.count(old)==1;changed=changed.replace(old,new,1)
   (c/unit['path']).write_text(changed)
  t=time.monotonic();p=subprocess.run(['godot','--headless','--path','godot','--script','test/construction_projection_fault_focus.gd'],cwd=c,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);log=p.stdout;(out/(name+'.log')).write_text(log);m=re.findall(r'(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)',log);counts=list(map(int,m[-1])) if m else None;errors=[x for x in log.splitlines() if 'ERROR:' in x or 'Parse Error:' in x];failures=re.findall(r'^\s+FAIL\s+(test_\w+)',log,re.M);valid=counts is not None and counts[0]==expected_tests and counts[1]>0 and not errors;expected=valid and ((p.returncode!=0 and counts[2]>0 and unit['expected_test'] in failures) if unit else p.returncode==0 and counts[2]==0)
  rec={'case':name,'seconds':round(time.monotonic()-t,3),'exit_code':p.returncode,'counts':counts,'valid_execution':valid,'expected_outcome':bool(expected),'failing_tests':failures,'errors':errors,'mutated_sha256':hashlib.sha256(changed.encode()).hexdigest() if changed else None,'log_sha256':hashlib.sha256(log.encode()).hexdigest()};results.append(rec);print(json.dumps({k:rec[k] for k in ['case','seconds','counts','valid_execution','expected_outcome']}),flush=True)
  if not expected:print(log[-4000:],flush=True);break
record={'source_sha256':{n:hashlib.sha256(s.encode()).hexdigest() for n,s in sources.items()},'seconds':round(time.monotonic()-start,3),'results':results,'source_unchanged':all((r/n).read_text()==s for n,s in sources.items())};record['passed']=record['source_unchanged'] and len(results)==len(units)+2 and all(x['expected_outcome'] for x in results);(out/'result.json').write_text(json.dumps(record,indent=2)+'\n');print('projection_purity_campaign_passed',record['passed']);raise SystemExit(0 if record['passed'] else 1)
