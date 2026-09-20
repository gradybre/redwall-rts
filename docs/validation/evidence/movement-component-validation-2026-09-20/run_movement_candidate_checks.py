from pathlib import Path
import tempfile,shutil,subprocess,json,hashlib,time
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/movement-component-validation-2026-09-20';plan=r/'docs/validation/evidence/movement-validation-planning-2026-09-20'
s=(r/'docs/validation/evidence/fishing-component-validation-2026-09-20/run_mutants.py').read_text().replace('63 source mutations','50 source mutations').replace('fishing','movement').replace('assert len(mutations)==41','assert len(mutations)==34').replace("assert len(results)==65 and sum(x['killed'] for x in results)==63","assert len(results)==52 and sum(x['killed'] for x in results)==50")
a=s.index('        fields=');b=s.index('\n        for field in fields:',a)
fields=json.loads((plan/'frozen-witnesses.json').read_text())['fields'];s=s[:a]+'        fields='+repr(fields)+s[b:]
s=s.replace("EXPECTED=len(re.findall(r'^func test_', (ROOT/'godot/test/test_save_owner_movement.gd').read_text(),re.M))", "EXPECTED=sum(len(re.findall(r'^func test_', (ROOT/p).read_text(),re.M)) for p in ['godot/test/test_save_owner_movement.gd','godot/test/test_movement_readmission.gd'])")
(e/'run_mutants.py').write_text(s);shutil.copy2(Path(__file__).parent/'movement_mutation_definitions.py',e/'owner_mutations.py')
focus='extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_save_owner_movement.gd","res://test/test_movement_readmission.gd"])\n'
(e/'candidate-focus.gd').write_text(focus)
inputs={
'godot/scripts/core/movement.gd':e/'candidate-movement.gd',
'godot/scripts/core/save_owner_movement.gd':e/'candidate-save_owner_movement.gd',
'godot/test/test_save_owner_movement.gd':plan/'parent-test-draft.gd',
'godot/test/test_movement_readmission.gd':plan/'parent-regression-draft.gd',
'godot/test/movement_validation_focus.gd':e/'candidate-focus.gd',
'tools/test_movement_metadata_preflights.py':plan/'parent-metadata-draft.py'}
identity={p:hashlib.sha256(f.read_bytes()).hexdigest() for p,f in inputs.items()}
record=dict(scope='Frozen candidate clone only, not production or full-suite acceptance',base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),input_sha256=identity,runs=[])
ce=e/'candidate-checks';ce.mkdir(exist_ok=True)
def run(clone,command,name,timeout):
 start=time.monotonic()
 with (ce/name).open('w') as output:p=subprocess.run(command,cwd=clone,stdout=output,stderr=subprocess.STDOUT,timeout=timeout)
 text=(ce/name).read_text();good=p.returncode==0 and 'SCRIPT ERROR:' not in text and 'Parse Error:' not in text
 record['runs'].append(dict(command=command,log=name,exit_code=p.returncode,valid=good,seconds=round(time.monotonic()-start,3)))
 (ce/'acceptance.json').write_text(json.dumps(record,indent=2)+'\n')
 print(name,p.returncode,round(time.monotonic()-start,2),flush=True)
 assert good,text[-4000:]
with tempfile.TemporaryDirectory(prefix='redwall-movement-integration-candidate-') as directory:
 clone=Path(directory);shutil.copytree(r/'godot',clone/'godot');(clone/'tools').mkdir();(clone/'docs').symlink_to(r/'docs',target_is_directory=True);(clone/'assets').symlink_to(r/'assets',target_is_directory=True)
 for p,f in inputs.items():shutil.copy2(f,clone/p)
 campaign=(e/'run_mutants.py').read_text().replace('ROOT=Path(__file__).resolve().parents[4]', 'ROOT=Path('+repr(str(clone))+')')
 (ce/'run_mutants.py').write_text(campaign);shutil.copy2(e/'owner_mutations.py',ce/'owner_mutations.py')
 run(clone,['godot','--headless','--path','godot','--script','res://test/movement_validation_focus.gd'],'focus.log',180)
 run(clone,['python3','tools/test_movement_metadata_preflights.py'],'metadata.log',600)
 run(clone,['python3',str(ce/'run_mutants.py')],'campaign.log',1800)
 for p,f in inputs.items():assert hashlib.sha256(f.read_bytes()).hexdigest()==identity[p];assert hashlib.sha256((clone/p).read_bytes()).hexdigest()==identity[p]
record['frozen_inputs_unchanged']=True
(ce/'acceptance.json').write_text(json.dumps(record,indent=2)+'\n')
print('Candidate clone campaign complete; production intake/full suite/independent review/CI still required.',flush=True)
