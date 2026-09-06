"""Fail-closed settlement performance evidence checker.

CSV timings are measured integer microseconds, never inferred from FPS averages.
This checker evaluates submitted evidence; it cannot authenticate physical hardware.
The complete capture protocol is in README.md. GDD §5.11, architecture §12.
"""
import argparse
import csv
from hashlib import sha256
import json
from pathlib import Path
import re

FEATURES={'packed_stores','needs_health','jobs_logistics','ecology','crops_weather',
          'rooms_heat','recipes_batches','social_mood','immigration_progression',
          'save_load','navigation','crowd_rendering','settlement_ui'}
SCENES={'dense_interiors','expiry_burst','season_crossing','queued_navigation','maximum_child_stores'}
PROFILES={'W-N':'NVIDIA GeForce GTX 1660 SUPER','W-A':'AMD Radeon RX 6600'}
FRAMES=('frame_id','elapsed_us','frame_us','sim_cpu_us','ui_cpu_us','sim_ram_bytes',
        'process_ram_bytes','skeletal_count','living','ticks_executed')
TICKS=('tick','frame_id','tick_cpu_us')
ROUTES=('request_id','request_us','ready_us')
SHA=re.compile(r'[0-9a-f]{64}')

def require(ok,message):
    if not ok:raise ValueError(message)

def percentile(values,p):
    require(bool(values),'No samples')
    require(1<=p<=100,'Invalid percentile')
    return sorted(values)[(len(values)*p+99)//100-1]

def integer(value):
    require(isinstance(value,str) and re.fullmatch(r'0|[1-9][0-9]*',value) is not None,
            'CSV measurement must be a nonnegative base-10 integer')
    return int(value)

def csv_rows(path,fields):
    with path.open(newline='') as f:
        reader=csv.DictReader(f)
        require(reader.fieldnames==list(fields),f'Wrong CSV columns: {path.name}')
        result=[]
        for row in reader:
            require(set(row)==set(fields),f'Malformed CSV row: {path.name}')
            result.append({key:integer(row[key]) for key in fields})
        require(bool(result),f'Empty capture: {path.name}')
        return result

def checked_file(base,descriptor):
    require(isinstance(descriptor,dict),'Missing file descriptor')
    relative=Path(descriptor['path'])
    require(not relative.is_absolute(),'Evidence paths must be relative')
    path=(base/relative).resolve()
    require(path.is_relative_to(base.resolve()),'Evidence path escapes its directory')
    require(path.is_file(),f'Missing evidence file: {relative}')
    require(SHA.fullmatch(descriptor['sha256']) is not None,'Invalid SHA-256')
    h=sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(65536),b''):h.update(block)
    require(h.hexdigest()==descriptor['sha256'],f'Evidence digest mismatch: {relative}')
    return path

def capture(meta,frames,ticks,routes):
    """A capture pass alone never awards full Windows qualification."""
    require(meta['profile'] in PROFILES,'Not a Windows reference profile')
    require(meta['os']=='Windows 11','Windows 11 capture required')
    require(meta['cpu']=='AMD Ryzen 5 3600','Reference CPU mismatch')
    require(meta['gpu']==PROFILES[meta['profile']],'Reference GPU mismatch')
    require(meta['ram_bytes']==17179869184,'Reference RAM mismatch')
    require(meta['driver'] in ('vulkan','d3d12'),'Driver outside target matrix')
    require(bool(meta['driver_version']),'GPU driver version missing')
    require(meta['engine']=='4.7.2.stable.official.ed1daf0bf','Engine pin mismatch')
    require(meta['build_mode']=='export_release' and meta['renderer']=='forward_plus','Release Forward+ capture required')
    require(meta['resolution']==[1920,1080] and meta['scale_per_mille']==1000,'Internal resolution mismatch')
    require(meta['viewports']==1 and meta['vsync'] is False and meta['frame_limit']==0,'Throughput capture setup mismatch')
    require(meta['speed'] in (1,4),'Capture speed must be 1 or 4')
    require(meta['warmup_us']>=60000000,'Less than 60 seconds warmup')
    require(FEATURES<=set(meta['features']),'Incomplete settlement runtime coverage')
    require(SCENES<=set(meta['exercised_scenes']),'Incomplete stress fixture coverage')
    require(meta['allocated_payload_bytes']>=57713254,'Full planned store allocation not exercised')
    require(meta['dropped_ticks']==0 and meta['speed_fallbacks']==0,'Capture skipped work or lowered speed')
    require(meta['kind'] in ('throughput','soak'),'Unknown capture kind')
    if meta['kind']=='throughput':require(meta['repeat'] in (1,2,3),'Invalid repeat')
    else:require(meta['repeat']==1,'Soak uses repeat 1')
    require(bool(frames) and bool(ticks) and bool(routes),'Missing measurement stream')
    required_us=1200000000 if meta['kind']=='soak' else 180000000
    require(frames[-1]['elapsed_us']>=required_us,'Recording is too short')
    frame_index={};elapsed=0
    for i,row in enumerate(frames,1):
        require(row['frame_id']==i,'Frame IDs must be contiguous starting at 1')
        require(row['elapsed_us']>elapsed and row['frame_us']==row['elapsed_us']-elapsed,'Frame clock mismatch')
        require(row['living']==256,'Capture does not maintain 256 living residents')
        require(row['sim_ram_bytes']>=57713254,'Simulation memory omits the required allocated stores')
        require(row['process_ram_bytes']>=row['sim_ram_bytes'],'Process memory excludes simulation allocations')
        require(row['ticks_executed']<=8,'Per-frame catch-up cap exceeded')
        require(row['sim_cpu_us']<=row['frame_us'],'Impossible single-thread simulation CPU measurement')
        frame_index[i]=row;elapsed=row['elapsed_us']
    tick_counts={};tick_cpu={}
    previous=ticks[0]['tick']-1
    for row in ticks:
        require(row['tick']==previous+1,'Missing or duplicate tick sample')
        previous=row['tick']
        require(row['frame_id'] in frame_index,'Tick refers to unknown frame')
        require(row['tick_cpu_us']>0,'Nonpositive tick timing')
        key=row['frame_id'];tick_counts[key]=tick_counts.get(key,0)+1
        tick_cpu[key]=tick_cpu.get(key,0)+row['tick_cpu_us']
    for key,row in frame_index.items():
        require(tick_counts.get(key,0)==row['ticks_executed'],'Tick/frame count mismatch')
        require(tick_cpu.get(key,0)<=row['sim_cpu_us'],'Aggregate simulation timing omits measured tick work')
    # Capture boundary may split at most one frame of the bounded scheduler [NEW].
    expected=elapsed*30*meta['speed']//1000000
    require(abs(len(ticks)-expected)<=8,'Simulation throughput does not match requested speed')
    route_ids=set()
    for row in routes:
        require(row['request_id'] not in route_ids,'Duplicate route request')
        route_ids.add(row['request_id'])
        require(row['request_us']<=elapsed,'Request outside measured interval')
        require(row['ready_us']>=row['request_us'],'Route never completed or clock is reversed')
    metrics={
        'frame_p95_us':percentile([r['frame_us'] for r in frames],95),
        'frame_p99_us':percentile([r['frame_us'] for r in frames],99),
        'tick_p99_us':percentile([r['tick_cpu_us'] for r in ticks],99),
        'simulation_frame_p95_us':percentile([r['sim_cpu_us'] for r in frames],95),
        'ui_p95_us':percentile([r['ui_cpu_us'] for r in frames],95),
        'simulation_peak_bytes':max(r['sim_ram_bytes'] for r in frames),
        'process_peak_bytes':max(r['process_ram_bytes'] for r in frames),
        'skeletal_peak':max(r['skeletal_count'] for r in frames),
        'route_p95_us':percentile([r['ready_us']-r['request_us'] for r in routes],95),
        'frame_samples':len(frames),'tick_samples':len(ticks),'route_samples':len(routes),
    }
    limits={'frame_p95_us':16670,'frame_p99_us':20000,'ui_p95_us':1500,
            'simulation_peak_bytes':100000000,'process_peak_bytes':4000000000,'skeletal_peak':24}
    if meta['speed']==1:limits.update(tick_p99_us=2000,route_p95_us=250000)
    else:limits['simulation_frame_p95_us']=6000
    failures=[f'{name}: {metrics[name]} > {limit}' for name,limit in limits.items() if metrics[name]>limit]
    return dict(status='FAIL' if failures else 'PASS_CAPTURE_ONLY',metrics=metrics,failures=failures)

def parity(left,right):
    """Streaming every-tick comparison; both files start at the same completed tick."""
    with left.open(newline='') as a,right.open(newline='') as b:
        aa=csv.DictReader(a);bb=csv.DictReader(b)
        require(aa.fieldnames==bb.fieldnames==['tick','state_sha256'],'Invalid parity columns')
        count=0;last=None
        while True:
            x=next(aa,None);y=next(bb,None)
            require((x is None)==(y is None),'Replay length mismatch')
            if x is None:break
            require(set(x)==set(y)=={'tick','state_sha256'},'Malformed replay row')
            t=integer(x['tick']);require(integer(y['tick'])==t,'Replay tick mismatch')
            require(last is None or t==last+1,'Missing replay tick')
            require(SHA.fullmatch(x['state_sha256']) is not None,'Malformed state digest')
            require(x['state_sha256']==y['state_sha256'],f'State divergence at tick {t}')
            last=t;count+=1
        require(count>=2,'Need saved boundary and at least the next tick')
        return count

def suite(path):
    if not path.is_file():
        return dict(status='BLOCKED',reasons=['No settlement qualification manifest or measured Windows evidence exists.'],captures=[])
    manifest=json.loads(path.read_text());base=path.parent
    require(manifest['schema_version']==1 and manifest['scope']=='settlement','Wrong evidence schema/scope')
    for name in ('build_sha256','rules_sha256','catalog_sha256','map_sha256'):
        require(SHA.fullmatch(manifest[name]) is not None,f'Missing provenance: {name}')
    require(re.fullmatch(r'[0-9a-f]{40}',manifest['source_commit']) is not None,'Missing source commit')
    require(SHA.fullmatch(manifest['source_diff_sha256']) is not None,'Missing dirty-source digest')
    captures=[];seen=set();reasons=[]
    for record in manifest['captures']:
        require(record['build_sha256']==manifest['build_sha256'],'Capture came from a different executable')
        m=record['metadata'];key=(m['profile'],m['driver'],m['speed'],m['kind'],m['repeat'])
        require(key not in seen,'Duplicate capture matrix entry');seen.add(key)
        streams=[csv_rows(checked_file(base,record[name]),fields) for name,fields in
                 [('frames',FRAMES),('ticks',TICKS),('routes',ROUTES)]]
        result=capture(m,*streams);result['matrix_key']=key;captures.append(result)
        if result['status']=='FAIL':reasons.append(f'Performance failure: {key}')
    wanted={(p,d,s,k,r) for p in PROFILES for d in ('vulkan','d3d12') for s in (1,4)
            for k in ('throughput','soak') for r in ((1,2,3) if k=='throughput' else (1,))}
    for key in sorted(wanted-seen):reasons.append(f'Missing capture: {key}')
    replay_seen=set();replay_inputs={}
    for record in manifest['parity']:
        require(record['platforms']==['macOS','Windows 11'],'Cross-platform parity requires both target platforms')
        require(record['engine']=='4.7.2.stable.official.ed1daf0bf','Replay engine mismatch')
        key=(record['fixture'],record['speed'])
        pair=(record['initial_state_sha256'],record['commands_sha256'])
        require(all(SHA.fullmatch(v) is not None for v in pair),'Missing replay input digests')
        prior=replay_inputs.setdefault(record['fixture'],pair)
        require(prior==pair,'Speeds were replayed from different inputs')
        require(key not in replay_seen,'Duplicate parity fixture');replay_seen.add(key)
        require(record['tested_save_load'] is True,'Uninterrupted replay is not save/load verification')
        require(record['same_initial_state_and_commands'] is True,'Unmatched replay inputs')
        left=checked_file(base,record['mac_uninterrupted'])
        right=checked_file(base,record['windows_reloaded'])
        count=parity(left,right)
        require(count>=751,'Replay must include at least one game hour after the saved boundary')
    for fixture in ('busy_construction','feast_preparation','winter_starvation'):
        for speed in (1,2,4):
            if (fixture,speed) not in replay_seen:reasons.append(f'Missing save/load parity: {fixture}, speed {speed}')
    # Visual correctness, cold-start and VSync repeats need separate capture review.
    for field in ('visual_review_passed','cold_start_review_passed','vsync_review_passed',
                  'transactional_peak_memory_passed','raw_route_log_complete'):
        if manifest.get(field) is not True:reasons.append(f'Missing reviewed evidence: {field}')
    worst={}
    for result in captures:
        profile,driver,speed,kind,repeat=result['matrix_key']
        key=f'{profile}/{driver}/{speed}x/{kind}'
        dest=worst.setdefault(key,{})
        for name,value in result['metrics'].items():
            if not name.endswith('_samples'):dest[name]=max(dest.get(name,0),value)
    return dict(status='FAIL_OR_INCOMPLETE' if reasons else 'PASS_SUBMITTED_EVIDENCE',reasons=reasons,captures=captures,worst_repeats=worst,
                limitation='Validates submitted records and attestations; does not independently authenticate hardware, scene coverage, or capture instrumentation.')

def main():
    p=argparse.ArgumentParser();p.add_argument('--manifest',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    try:result=suite(a.manifest)
    except (ValueError,KeyError,TypeError,OSError) as e:result=dict(status='INVALID_EVIDENCE',reasons=[str(e)],captures=[])
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
    raise SystemExit(0 if result['status']=='PASS_SUBMITTED_EVIDENCE' else 2)

if __name__=='__main__':main()
