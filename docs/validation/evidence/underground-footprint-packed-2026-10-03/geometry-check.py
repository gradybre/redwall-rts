import pathlib,tempfile,subprocess,shutil,sys
root=pathlib.Path.cwd();out=pathlib.Path(tempfile.mkdtemp(prefix='ug1094-packed-'));print(out,flush=True)
assets=root/'godot/demo/assets';moved=out/'demo-assets'
try:
 if assets.exists():shutil.move(str(assets),str(moved))
 shutil.rmtree(root/'godot/.godot',ignore_errors=True)
 with (out/'import.log').open('w') as f:
  result=subprocess.run(['godot','--headless','--path','godot','--editor','--quit'],stdout=f,stderr=subprocess.STDOUT)
 errors=[x for x in (out/'import.log').read_text().splitlines() if 'ERROR' in x or 'SCRIPT ERROR' in x or 'WARNING' in x]
 print('import',result.returncode,errors[:30],flush=True)
 if result.returncode or errors:sys.exit(1)
 sys.exit(subprocess.run(['python3','/tmp/ug-run-focused.py',str(out),'test_room_footprint_packed.gd','test_room_footprint.gd','test_room_layout.gd']).returncode)
finally:
 if moved.exists():shutil.move(str(moved),str(assets))
