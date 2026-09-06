"""Run the isolated Godot suite, compare Python outcomes and retain portable evidence.

Usage: python3 -B docs/validation/run_headless.py --godot /path/to/godot --output validation-results/godot-mac
Windows: py -3 docs/validation/run_headless.py --godot C:/Godot/Godot_console.exe --output validation-results/godot-user-pc
"""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time
from qualify import parity

ENGINE='4.7.2.stable.official.ed1daf0bf'

def digest(path):
    return sha256(path.read_bytes()).hexdigest()

def same_result(left,right,path='results'):
    if type(left) is not type(right):raise ValueError(f'{path}: type differs')
    if isinstance(left,dict):
        if left.keys()!=right.keys():raise ValueError(f'{path}: field names differ')
        for key in left:same_result(left[key],right[key],f'{path}.{key}')
    elif isinstance(left,list):
        if len(left)!=len(right):raise ValueError(f'{path}: list length differs')
        for index,(a,b) in enumerate(zip(left,right)):same_result(a,b,f'{path}[{index}]')
    elif left!=right:raise ValueError(f'{path}: Python={left}, Godot={right}')

def inspect_log(output):
    """Preserve known sandbox startup diagnostics, reject other engine/script errors."""
    lines=output.splitlines();known=[]
    for i,line in enumerate(lines):
        if 'SCRIPT ERROR:' in line or 'instances leaked' in line:
            raise ValueError(f'Godot runtime error: {line}')
        if not line.startswith('ERROR:'):continue
        if ('Could not create directory:' in line or 'Error attempting to create data dir:' in line) and 'Redwall Settlement Validation' in line:
            known.append(line)
        elif 'Condition "ret != noErr"' in line and i+1<len(lines) and 'get_system_ca_certificates' in lines[i+1]:
            known.append(line)
        else:raise ValueError(f'Unrecognized engine error: {line}')
    return known

def execute(args):
    base=Path(__file__).resolve().parent
    root=base.parents[1]
    executable=shutil.which(str(args.godot))
    if not executable:raise ValueError('Godot executable not found')
    version=subprocess.run([executable,'--version'],capture_output=True,text=True,check=True,timeout=20).stdout.strip()
    if version!=ENGINE:raise ValueError(f'Pinned Godot required: found {version}')
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    report_path=output/'report.json'
    if args.checkpoint_input and args.checkpoint_input.resolve()==output/'winter.control':
        raise ValueError('Input checkpoint must be separate from the output checkpoint')
    if report_path.exists():report_path.unlink()
    command=[executable,'--headless','--path',str(base/'headless'),'--log-file',str(output/'engine.log'),
             '--script','run_controls.gd','--quit-after','2','--','--output',str(report_path)]
    if args.checkpoint_input:command+=['--checkpoint-input',str(args.checkpoint_input.resolve())]
    started=time.monotonic_ns()
    run=subprocess.run(command,capture_output=True,text=True,timeout=args.timeout)
    duration_ms=(time.monotonic_ns()-started)//1000000
    log=run.stdout+run.stderr
    (output/'console.log').write_text(log)
    known=inspect_log(log)
    if run.returncode!=0:raise ValueError(f'Godot exited {run.returncode}; see console.log')
    report=json.loads(report_path.read_text())
    if report['status']!='PASS_ISOLATED_GODOT_CONTROL' or report['failures']:
        raise ValueError(f'Godot checks failed: {report["failures"]}')
    reference_path=args.reference.resolve()
    reference=json.loads(reference_path.read_text())
    if reference['code_sha256']!=digest(base/'winter.py'):raise ValueError('Python reference has stale code digest; regenerate it')
    for name,sha in reference['source_sha256'].items():
        if digest(root/'docs'/name)!=sha:raise ValueError(f'Python reference uses different source document: {name}')
    same_result(reference['results'],report['results'])
    comparison=dict(status='PASS_SAME_PLATFORM_REFERENCE',godot_checks=report['checks'],engine=version,
                    platform=report['platform'],python_results='EXACT_MATCH',
                    daily_and_terminal_rows=sum(len(r['daily']) for r in report['results']),
                    death_events=sum(len(r['events']) for r in report['results']),
                    next_tick_comparisons=report['checkpoint_parity']['compared_ticks'],
                    speed_parity=report['foundation']['same_state_across_speeds'],
                    observed_runner_duration_ms=duration_ms,known_environment_diagnostics=known,
                    source_sha256={p.name:digest(p) for p in sorted((base/'headless').glob('*.gd'))},
                    evidence_sha256={p.name:digest(p) for p in (report_path,output/'winter.control',output/'checkpoint_hashes.csv')},
                    python_reference_sha256=digest(reference_path),
                    limitation='Isolated headless engine controls; not the full settlement runtime, release save format, renderer or Windows-floor performance qualification.')
    if args.compare_mac:
        mac=args.compare_mac.resolve()
        original=json.loads((mac/'report.json').read_text())
        if original['platform']!='macOS':raise ValueError('Comparison baseline is not a Mac capture')
        baseline=json.loads((mac/'comparison.json').read_text())
        if baseline['source_sha256']!=comparison['source_sha256']:raise ValueError('Mac baseline used different GDScript source')
        same_result(original['results'],report['results'])
        count=parity(mac/'checkpoint_hashes.csv',output/'checkpoint_hashes.csv')
        if count!=15001:raise ValueError('Expected saved boundary plus 15000 subsequent ticks')
        comparison['comparison_with_mac']=dict(compared_hash_rows=count,
            cross_platform=report['platform']!=original['platform'],
            loaded_mac_checkpoint=bool(args.checkpoint_input and digest(args.checkpoint_input)==digest(mac/'winter.control')))
        if report['platform']=='Windows' and comparison['comparison_with_mac']['loaded_mac_checkpoint']:
            comparison['status']='PASS_ISOLATED_MAC_WINDOWS_PARITY'
    (output/'comparison.json').write_text(json.dumps(comparison,indent=2)+'\n')
    return comparison

def main():
    root=Path(__file__).resolve().parents[2]
    p=argparse.ArgumentParser()
    p.add_argument('--godot',default='godot')
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--reference',type=Path,default=root/'validation-results/winter-controls/winter_report.json')
    p.add_argument('--checkpoint-input',type=Path)
    p.add_argument('--compare-mac',type=Path)
    p.add_argument('--timeout',type=int,default=180)
    args=p.parse_args()
    try:
        result=execute(args)
        print(json.dumps({k:v for k,v in result.items() if not k.endswith('sha256')},indent=2))
    except (ValueError,KeyError,OSError,subprocess.SubprocessError) as error:
        args.output.mkdir(parents=True,exist_ok=True)
        result=dict(status='FAIL_OR_INCOMPLETE',reason=str(error))
        (args.output/'comparison.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result,indent=2),file=sys.stderr)
        raise SystemExit(2)

if __name__=='__main__':main()
