#!/usr/bin/env python3
"""Create-only actual poll-setting witness with isolated user data and pre/post source closure."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('install_native_base', HERE/'run_high_wall.py')
H = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(H)
BASE = H.BASE


def bounded_json(path, maximum):
    if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= maximum:
        raise ValueError('INSTALL_NATIVE_METADATA_CAPACITY')
    return json.loads(path.read_text())


def source_metadata(preview):
    compiled = bounded_json(preview/'compilation.json', 65536)
    candidate = bounded_json(preview/'candidate.json', 1048576)
    image = preview/'mole-worker.ugactor'
    table = BASE.wire_timing({'content':str(image),'content_sha256':compiled['content_sha256']})
    raw = image.read_bytes()
    if (hashlib.sha256((preview/'candidate.json').read_bytes()).hexdigest() != raw[120:152].hex() or
            hashlib.sha256((preview/'plan.json').read_bytes()).hexdigest() != raw[152:184].hex() or
            compiled.get('production_qualified') is not False or candidate.get('production_qualified') is not False or
            table != [(0,33,0,32*65536),(33,31,0,30*65536),(64,31,0,30*65536)] or
            candidate.get('source_triangle_census') != [10209,1150] or candidate.get('poll_source_vertex') != 478 or
            candidate.get('contact_source_point_m') != [-0.5544813275337219,0.126980260014534,0.7396608591079712]):
        raise ValueError('INSTALL_NATIVE_SOURCE_CENSUS')
    pins = candidate.get('producer_sources')
    if type(pins) is not dict or not 1 <= len(pins) <= 32:
        raise ValueError('INSTALL_NATIVE_PRODUCERS')
    for path, digest in pins.items():
        if BASE.digest(BASE.ROOT/path) != digest:
            raise ValueError('INSTALL_NATIVE_PRODUCER_DRIFT')
    return compiled, candidate, table


def fixture_rows(prefix, targets):
    if len(targets) != 2 or prefix.get('engineering_only') is not True:
        raise ValueError('INSTALL_NATIVE_PREFIX')
    # L0's exterior half-space is still natural: the actual future pocket ends
    # at local Z=-512. These finite witness bounds are not a support permission.
    earth = [[-2048,-1024,-512,2048,0,1024]]
    root = targets[1]['station_root_u']
    timber = [[v-root[i%3] for i,v in enumerate(part['bounds_u'])]
              for part in prefix['parts'] if part['assembly']==0]
    if len(timber) != 7 or [row['existing_target_kind'] for row in targets] != ['retained_natural','installed_part']:
        raise ValueError('INSTALL_NATIVE_TARGET_IDENTITY')
    return [earth,timber]


def validate_report(report, spec):
    expected = 6*sum(time//32768+1 for time in spec['duration_q16'])+9
    if (report.get('content_sha256') != spec['content_sha256'] or report.get('production_qualified') is not False or
            report.get('targets') != spec['targets'] or type(report.get('poses')) is not int or report['poses'] != expected or
            type(report.get('assertions')) is not int or report['assertions'] < 2*expected or report.get('failures') != [] or
            not str(report.get('user_directory','')).endswith('/'+spec['user_directory_name'])):
        raise ValueError('INSTALL_NATIVE_REPORT')
    points = report.get('native_poll')
    if type(points) is not list or len(points) != 9 or any(row.get('share_q16') != i*8192 or
            type(row.get('local_point_u')) is not list or len(row['local_point_u']) != 3 or
            any(type(v) not in (float,int) or not math.isfinite(v) for v in row['local_point_u'])
            for i,row in enumerate(points)) or points[0]['local_point_u'][1] <= 0 or points[-1]['local_point_u'][1] >= 0:
        raise ValueError('INSTALL_NATIVE_POLL_CROSSING')
    shots = report.get('screenshots')
    if type(shots) is not list or len(shots) != 132 or len({row.get('path') for row in shots}) != 132:
        raise ValueError('INSTALL_NATIVE_IMAGE_CENSUS')
    return {'poses':expected,'assertions':report['assertions'],'screenshots':132,'native_poll_samples':9,
            'production_qualified':False,'scope':'actual source/native fixture only; no paid target/support/BUILD permission'}


def run(preview, out):
    compiled,candidate,table = source_metadata(preview)
    script,bake = HERE/'capture_install_source.gd',HERE/'high-wall-runtime-sources-v1/bake-spec.json'
    before = H.pre_import_pins(script,bake)
    for path in [Path(__file__).resolve(), *preview.iterdir()]:
        if path.is_file(): before[str(path)] = BASE.digest(path)
    prefix_path = HERE/'stair-sequence-prefix-v1/first-entry-prefix-v1.source.json'
    if BASE.digest(prefix_path) != candidate['prefix_source_sha256']:
        raise ValueError('INSTALL_NATIVE_PREFIX_DRIFT')
    prefix=bounded_json(prefix_path,65536);before[str(prefix_path)]=BASE.digest(prefix_path)
    override=BASE.ROOT/'godot/override.cfg'
    if override.exists() or override.is_symlink(): raise ValueError('INSTALL_NATIVE_OVERRIDE_EXISTS')
    name='Redwall-Codex-Install-'+hashlib.sha256(str(out).encode()).hexdigest()[:16]
    override_raw=('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+name+'"\n').encode()
    out.mkdir(parents=True);(out/'.gdignore').touch();(out/'runtime-override.cfg.txt').write_bytes(override_raw)
    with override.open('xb') as stream: stream.write(override_raw)
    try:
        execute(preview,out,compiled,candidate,table,before,prefix,script,bake,name,override,override_raw)
    finally:
        if override.read_bytes() != override_raw: raise ValueError('INSTALL_NATIVE_OVERRIDE_DRIFT')
        override.unlink()
        (out/'override-restoration.json').write_text(json.dumps({'originally_absent':True,'removed_own_override':True,
            'sha256':hashlib.sha256(override_raw).hexdigest(),'user_directory_name':name},indent=2)+'\n')


def execute(preview,out,compiled,candidate,table,before,prefix,script,bake,name,override,override_raw):
    (out/'pre-import-sources.json').write_text(json.dumps(before,indent=2)+'\n')
    imported=['godot','--headless','--path','godot','--editor','--quit','--log-file',str(out/'engine-import.log')]
    with (out/'import.log').open('x') as log:
        code=subprocess.run(imported,cwd=BASE.ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600).returncode
    if code or BASE.DIAGNOSTIC.search((out/'import.log').read_text()): raise ValueError('INSTALL_NATIVE_IMPORT')
    after_import={path:BASE.digest(Path(path)) if Path(path).is_file() else None for path in before}
    (out/'pre-import-after.json').write_text(json.dumps(after_import,indent=2)+'\n')
    if before != after_import or override.read_bytes() != override_raw: raise ValueError('INSTALL_NATIVE_IMPORT_DRIFT')
    restored=H.restore_pinned_imports(bake,BASE.ROOT/'godot/demo/assets/underground-matrices/mole-grip-v3.inputs',BASE.ROOT)
    (out/'import-cache-restoration.json').write_text(json.dumps(restored,indent=2)+'\n')
    pins=dict(BASE.closure(script,bake),**before)
    spec=json.loads((HERE.parent/'grip-native-v2/spec.json').read_text())
    spec.update(content=str(preview/'mole-worker.ugactor'),content_sha256=compiled['content_sha256'],
        reserve_bytes=compiled['presentation_budget']['admitted_peak_bytes'], duration_q16=[row[3] for row in table],
        targets=candidate['targets'],fixtures=fixture_rows(prefix,candidate['targets']),poll_vertex=478,
        poll_source_m=candidate['contact_source_point_m'],contact_source_kind=candidate['contact_source_kind'],
        user_directory_name=name,production_qualified=False)
    for key in ('content','basis','manifest'):
        path=BASE.actual(spec[key]).resolve();pins[str(path)]=BASE.digest(path)
    (out/'sources.json').write_text(json.dumps(pins,indent=2)+'\n');(out/'spec.json').write_text(json.dumps(spec,indent=2)+'\n')
    command=['godot','--path','godot','--rendering-method','gl_compatibility','--audio-driver','Dummy','--fixed-fps','60',
        '--log-file',str(out/'engine-native.log'),'--script',str(script),'--',str(out/'spec.json'),str(out)]
    with (out/'native.log').open('x') as log:
        code=subprocess.run(command,cwd=BASE.ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600).returncode
    after={path:BASE.digest(Path(path)) if Path(path).is_file() else None for path in pins}
    (out/'sources-after.json').write_text(json.dumps(after,indent=2)+'\n')
    bad=bool(BASE.DIAGNOSTIC.search((out/'native.log').read_text()))
    invocation={'commands':[imported,command],'native_exit':code,'source_unchanged':pins==after,
        'unexpected_diagnostics':bad,'production_qualified':False,'pre_import_source_unchanged':before==after_import,
        'isolated_override_unchanged':override.read_bytes()==override_raw,'override_sha256':hashlib.sha256(override_raw).hexdigest()}
    (out/'invocation.json').write_text(json.dumps(invocation,indent=2)+'\n')
    if code or bad or pins!=after or override.read_bytes()!=override_raw: raise ValueError('INSTALL_NATIVE_OR_DRIFT')
    report=bounded_json(out/'report.json',1048576);verified=validate_report(report,spec)
    for row in report['screenshots']:
        path=Path(row['path'])
        if path.name != str(path) or path.suffix != '.png' or BASE.digest(out/path) != row.get('sha256'):
            raise ValueError('INSTALL_NATIVE_IMAGE_HASH')
    (out/'verification.json').write_text(json.dumps(verified,indent=2)+'\n')
    print(json.dumps({**invocation,**verified},indent=2))


def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('preview',type=Path);parser.add_argument('out',type=Path)
    args=parser.parse_args()
    if args.out.exists() or args.out.is_symlink(): raise ValueError('INSTALL_NATIVE_OUTPUT_EXISTS')
    run(args.preview.resolve(),args.out.resolve())


if __name__=='__main__': main()
