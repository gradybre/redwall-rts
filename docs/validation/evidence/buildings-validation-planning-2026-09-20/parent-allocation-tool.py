#!/usr/bin/env python3
"""Actual Buildings adapter static-allocation discriminator, not RSS qualification."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
BRIDGE=Path('godot/scripts/core/save_owner_buildings.gd')
PROBE=Path('docs/validation/evidence/buildings-validation-planning-2026-09-20/parent-allocation-probe.gd')
def execute(clone,label,expected):
    p=subprocess.run(['godot','--headless','--path','godot','--script','res://test/buildings_allocation_probe.gd'],cwd=clone,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
    matches=re.findall(r'^BUILDINGS_ALLOCATION (.+)$',p.stdout,re.M)
    assert len(matches)==1 and 'SCRIPT ERROR:' not in p.stdout and 'Parse Error:' not in p.stdout,label+'\n'+p.stdout
    result=json.loads(matches[0]);result['case']=label
    assert (result['status'],result['code'],p.returncode)==expected,(label,result,p.stdout)
    assert result['prior_usage']>0 and result['lifted_usage']>result['prior_peak']>0
    assert result['after_peak']>=result['before_peak']>=result['lifted_usage']
    return result

def main():
    paths=[BRIDGE,Path('godot/scripts/core/buildings.gd'),Path('godot/scripts/core/save_section_component_columns.gd'),Path('godot/scripts/core/save_component_columns_schema.gd'),Path('godot/project.godot'),PROBE]
    originals={p:(ROOT/p).read_bytes() for p in paths}
    results=[]
    try:
        with tempfile.TemporaryDirectory(prefix='redwall-buildings-allocation-') as temp:
            clone=Path(temp);shutil.copytree(ROOT/'godot',clone/'godot')
            (clone/'docs').symlink_to(ROOT/'docs',target_is_directory=True)
            (clone/'assets').symlink_to(ROOT/'assets',target_is_directory=True)
            project=clone/'godot/project.godot';config,n=re.subn(r'(?ms)^\[autoload\]\n.*?(?=^\[|\Z)','',project.read_text());assert n==1;project.write_text(config)
            (clone/'godot/test/buildings_allocation_probe.gd').write_bytes(originals[PROBE])
            results.append(execute(clone,'baseline',('PASS','',0)))
            source=originals[BRIDGE].decode();needle='	var columns: Buildings.Columns = Buildings.Columns.new(false)';assert source.count(needle)==1
            (clone/BRIDGE).write_text(source.replace(needle,needle.replace('new(false)','new()')))
            results.append(execute(clone,'forbidden-default-constructor',('FAIL','ALLOCATION_EXTRA_OWNER',1)))
            (clone/BRIDGE).write_bytes(originals[BRIDGE])
            results.append(execute(clone,'restored',('PASS','',0)))
    finally:
        for p,data in originals.items():assert (ROOT/p).read_bytes()==data,p
    print(json.dumps(dict(status='PASS',scope='Cold actual-adapter incremental Godot static allocation; ballast is apparatus, not game budget or process RSS',cases=results,source_sha256={str(p):hashlib.sha256(d).hexdigest() for p,d in originals.items()}),indent=2))
if __name__=='__main__':main()
