from pathlib import Path
import tempfile,shutil,subprocess,json,hashlib,time
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/movement-component-validation-2026-09-20';plan=r/'docs/validation/evidence/movement-validation-planning-2026-09-20'
s=(plan/'parent-test-draft.gd').read_text();consts=s[s.index('const FIELDS:'):s.index('func _put(')];helpers=s[s.index('func _put('):s.index('func _frame(')]+s[s.index('func _fill('):s.index('func _expect(')];physical=s[s.index('func test_every_field_at_every_physical_row('):s.index('func test_full_capacity_mixed_phase_and_retained_history(')]
physical=physical.replace('\t\t\tif row == 0 or row == 511: _expect(c,codes[field],"bridge edges")\n','').replace('\t_expect(c,&"","restored clear")','\tassert_equal(Owner.columns_refusal(c),&"","restored clear")')
probe='extends "res://test/framework/test_case.gd"\nconst Owner := preload("res://scripts/core/movement.gd")\n'+consts+helpers+'''
func test_frozen_candidate_images() -> void:
	for item: Array in CASES:
		var c: Owner.Columns = _image(item[1])
		for change: Array in item[2]: _put(c,FIELDS.find(change[0]),int(change[1]),int(change[2]))
		var before: Array = _snapshot(c)
		assert_equal(Owner.columns_refusal(c),StringName(item[3]),item[0])
		for field: int in 16: assert_true(c.get(FIELDS[field]) == before[field],"candidate input unchanged")
	assert_equal(Owner.columns_refusal(null),&"COLUMN_SHAPE","null")
'''+physical
(e/'owner-candidate-probe.gd').write_text(probe)
with tempfile.TemporaryDirectory(prefix='redwall-movement-owner-candidate-') as scratch:
 clone=Path(scratch);shutil.copytree(r/'godot',clone/'godot');(clone/'docs').symlink_to(r/'docs',target_is_directory=True);(clone/'assets').symlink_to(r/'assets',target_is_directory=True)
 shutil.copy2(e/'candidate-movement.gd',clone/'godot/scripts/core/movement.gd')
 (clone/'godot/test/test_movement_owner_candidate.gd').write_text(probe)
 shutil.copy2(plan/'parent-regression-draft.gd',clone/'godot/test/test_movement_readmission.gd')
 (clone/'godot/test/movement_owner_candidate_focus.gd').write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_movement.gd","res://test/test_movement_owner_candidate.gd","res://test/test_movement_readmission.gd"])\n')
 start=time.monotonic();p=subprocess.run(['godot','--headless','--path','godot','--script','res://test/movement_owner_candidate_focus.gd'],cwd=clone,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
 (e/'owner-candidate-probe.log').write_text(p.stdout)
 (e/'owner-candidate-probe.json').write_text(json.dumps(dict(scope='Candidate clone only, original Movement suite plus156explicit images/every field at every physical row and five public readmission regressions; no bridge or production acceptance',exit_code=p.returncode,seconds=round(time.monotonic()-start,3),candidate_sha256=hashlib.sha256((e/'candidate-movement.gd').read_bytes()).hexdigest()),indent=2)+'\n')
 print(p.stdout[-3000:]);assert p.returncode==0 and 'SCRIPT ERROR:' not in p.stdout and ' 0 failure(s)' in p.stdout
