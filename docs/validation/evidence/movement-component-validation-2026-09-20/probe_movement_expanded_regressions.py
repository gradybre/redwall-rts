from pathlib import Path
import tempfile,shutil,subprocess,json,time,hashlib
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/movement-validation-planning-2026-09-20';s=(e/'parent-regression-draft.gd').read_text()
with tempfile.TemporaryDirectory(prefix='redwall-movement-readmission-') as scratch:
 clone=Path(scratch);shutil.copytree(r/'godot',clone/'godot');(clone/'docs').symlink_to(r/'docs',target_is_directory=True);(clone/'assets').symlink_to(r/'assets',target_is_directory=True)
 (clone/'godot/test/test_movement_readmission_probe.gd').write_text(s)
 (clone/'godot/test/movement_readmission_focus.gd').write_text('extends "res://test/run_tests.gd"\nfunc _discover_suites() -> PackedStringArray:\n\treturn PackedStringArray(["res://test/test_movement_readmission_probe.gd"])\n')
 start=time.monotonic();p=subprocess.run(['godot','--headless','--path','godot','--script','res://test/movement_readmission_focus.gd'],cwd=clone,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
 (e/'readmission-expanded-original.log').write_text(p.stdout);(e/'readmission-expanded-original.json').write_text(json.dumps(dict(scope='Normative public regression on original source; failures are evidence of defect, not acceptance',exit_code=p.returncode,seconds=round(time.monotonic()-start,3),source_sha256=hashlib.sha256((r/'godot/scripts/core/movement.gd').read_bytes()).hexdigest()),indent=2)+'\n')
 print(p.stdout[-4000:]);assert p.returncode!=0 and 'SCRIPT ERROR:' not in p.stdout and '5 test(s)' in p.stdout
