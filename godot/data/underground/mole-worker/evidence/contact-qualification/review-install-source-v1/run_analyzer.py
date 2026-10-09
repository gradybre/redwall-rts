#!/usr/bin/env python3
"""Isolated-user-data scoped analyzer; never mutate another checkout or reuse a foreign override."""
from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
assert (ROOT/'godot/project.godot').is_file()
source=HERE.parent/'capture_install_source.gd'
override=ROOT/'godot/override.cfg'
if override.exists() or override.is_symlink(): raise ValueError('INSTALL_ANALYZER_OVERRIDE_EXISTS')
outputs=[HERE/'analyzer.log',HERE/'analyzer.json',HERE/'analyzer-invocation.json']
if any(p.exists() or p.is_symlink() for p in outputs):raise ValueError('INSTALL_ANALYZER_OUTPUT_EXISTS')
raw=b'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-Codex-Install-Analyzer-v1"\n'
before=hashlib.sha256(source.read_bytes()).hexdigest()
command=['python3','tools/gdscript_warnings.py','--max','0','--port','6149','--json',str(outputs[1]),str(source)]
with override.open('xb') as f:f.write(raw)
try:
 with outputs[0].open('x') as log:code=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600).returncode
 unchanged=hashlib.sha256(source.read_bytes()).hexdigest()==before
 if override.read_bytes()!=raw:raise ValueError('INSTALL_ANALYZER_OVERRIDE_DRIFT')
 outputs[2].write_text(json.dumps({'command':command,'exit_code':code,'source_sha256':before,'source_unchanged':unchanged,
  'isolated_override_sha256':hashlib.sha256(raw).hexdigest(),'user_directory_name':'Redwall-Codex-Install-Analyzer-v1'},indent=2)+'\n')
 if code or not unchanged:raise ValueError('INSTALL_ANALYZER_REFUSAL')
finally:
 if override.read_bytes()!=raw:raise ValueError('INSTALL_ANALYZER_OVERRIDE_DRIFT')
 override.unlink()
