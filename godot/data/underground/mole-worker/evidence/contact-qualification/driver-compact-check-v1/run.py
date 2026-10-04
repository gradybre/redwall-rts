from pathlib import Path
import hashlib, importlib.util, json, re, shutil, subprocess
ROOT=Path(__file__).resolve().parents[7]
OUT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("shards",ROOT/"tools/ci_test_shards.py")
shards=importlib.util.module_from_spec(spec);spec.loader.exec_module(shards)
files=("godot/data/underground/mole-worker/mole_profile_driver.gd","godot/test/test_mole_profile_driver.gd")
def pins():return {name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files}
before=pins()
plan=shards.make_plan(len(shards.discover(ROOT)),ROOT)
index=next(i for i,names in enumerate(plan["shards"]) if names==["test_mole_profile_driver.gd"])
commands=[["godot","--headless","--path","godot","--editor","--quit"],
["./tools/run_tests.sh","--shard",str(index)+"/"+str(plan["shard_count"]),"--output-dir",str(OUT/"shard")],
["python3","tools/gdscript_warnings.py",*files,"--port","6149","--max","0"]]
(OUT/"commands.json").write_text(json.dumps(commands,indent=2)+"\n")
(OUT/"source-sha256.json").write_text(json.dumps(before,indent=2)+"\n")
assets=ROOT/"godot/demo/assets";saved=ROOT/".profile-clean-assets-aside"
if saved.exists() or saved.is_symlink():raise ValueError("existing assets-aside directory")
moved=False;codes=[];bad=False
try:
    if assets.exists():assets.rename(saved);moved=True
    cache=ROOT/"godot/.godot"
    if cache.exists():shutil.rmtree(cache)
    for command,name in zip(commands,("import.log","strict.log","analyzer.log")):
        with (OUT/name).open("x") as log:
            code=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600).returncode
        codes.append(code)
        text=(OUT/name).read_text()
        bad=bad or bool(re.search(r"^(?:SCRIPT ERROR|ERROR|WARNING):|ObjectDB instances? (?:were|was) leaked|resources still in use at exit",text,re.M))
        if code or bad:break
        if name=="strict.log":shards.parse_log(text)
finally:
    if moved:saved.rename(assets)
after=pins()
(OUT/"verification.json").write_text(json.dumps({"returncodes":codes,"diagnostic_failure":bad,"source_unchanged":before==after,"source_after":after,"assets_restored":not saved.exists()},indent=2)+"\n")
print("codes",codes,"diagnostics",bad,"source_unchanged",before==after,flush=True)
raise SystemExit(0 if codes==[0,0,0] and not bad and before==after else 2)
