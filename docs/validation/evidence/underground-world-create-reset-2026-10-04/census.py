#!/usr/bin/env python3
"""Compose bounded UI reset caller frames with accepted1158; native widths are provisional."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[4]
HERE=Path(__file__).resolve().parent
OLD=ROOT/'docs/validation/evidence/underground-host-retirement-2026-10-04/census.py'
SPEC=importlib.util.spec_from_file_location('accepted_host_census',OLD)
H=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(H)
FILES={'UI':'godot/scripts/systems/ui_manager.gd','Form':'godot/scripts/ui/ui_world_session.gd'}
SELECTED={
 'UI':['create_world','_prepare_world_create','_create_world_after_abandon','_reset_for_create_into',
       '_materialize_after_create','_restore_underground_after_create','_cleanup_failed_create',
       '_report_generation','_report_generation_failure','_reset_outcome_text'],
 'Form':['create_with_cohort_into','_preflight_cohort_world','record_reset_outcome','_publish_cohort_world',
         'refuse_create','_report_refusal','refuse_published_world'],
}


def require(condition,message):
    if not condition: raise ValueError(message)


def digest(data): return hashlib.sha256(data).hexdigest()


def prior():
    rows=json.loads((HERE/'predecessor/manifest.json').read_text())
    for name,row in rows.items(): require(digest((ROOT/row['locator']).read_bytes())==row['sha256'],'predecessor drift '+name)
    return {k:(ROOT/rows[v]['locator']).read_text() for k,v in FILES.items()}


def class_fields(source,name):
    part=source.split('class '+name+':\n',1)[1]
    part=re.split(r'^\S',part,maxsplit=1,flags=re.M)[0]
    rows=dict(re.findall(r'^\tvar (\w+): ([\w.]+)',part,re.M))
    require(len(rows)==len(re.findall(r'^\tvar ',part,re.M)), 'typed class fields')
    return rows


def function(source,name):
    return re.search(r'^func '+name+r'\(.*?(?=^func |\Z)',source,re.M|re.S).group()


def build(replacements=None):
    old=prior();sources={k:(ROOT/v).read_text() for k,v in FILES.items()};sources.update(replacements or {})
    base=H.build(ROOT)
    for module in FILES:
        before,after=H.members(old[module]),H.members(sources[module])
        extra={k:v for k,v in after.items() if k not in before}
        require(extra==({'_creating_world':'bool'} if module=='UI' else {}),'exact retained UI fields')
        require(all(after.get(k)==v for k,v in before.items()),'existing member types preserved')
        require(re.findall(r'^var \w+: Packed.*$',sources[module],re.M)==re.findall(r'^var \w+: Packed.*$',old[module],re.M),'no packed bank delta')
    before=class_fields(old['Form'],'Report');after=class_fields(sources['Form'],'Report')
    require({k:v for k,v in after.items() if k not in before}==
            {'reset_observed':'bool','reset_state':'int','reset_error':'StringName'},'bounded report delta')
    require(all(after.get(k)==v for k,v in before.items()),'original report fields')
    outcome=class_fields(sources['Form'],'ResetOutcome')
    require(outcome=={'state':'int','error':'StringName'},'fixed outcome scalar packet')
    require(function(sources['Form'],'create_into')==function(old['Form'],'create_into'),'standalone generation unchanged')
    require('var state: int = RESET_STOPPED' in sources['Form'],'default stopped')
    for name,value in [('CLEARED',0),('RETAINED',1),('STOPPED',2)]:
        require(f'const RESET_{name}: int = {value}\n' in sources['Form'],'exact enum')
    frames={k:dict(v) for k,v in base['frames'].items()}
    own={}
    for module,names in SELECTED.items():
        parsed=H.parse(sources[module],module)
        for name in names:
            key=module+'.'+name;row=parsed[key]
            require(all(t not in ('Variant','Array','Dictionary') and not t.startswith('Packed') for _,t in row['values']), 'bounded helper '+key)
            code=re.sub(r'""".*?"""|#[^\n]*','',row['body'],flags=re.S)
            row['allocations']=len(re.findall(r'\b(?:UiWorldSession\.)?ResetOutcome\.new\(\)',code))
            require(not re.search(r'\bfor ',code),'loop lifetime needs explicit bound '+key)
            if module=='UI':
                row['calls']+=['Form.'+m for m in re.findall(r'\b_session\.([_a-z]\w*)\(',code)]
                row['calls']+=['Host.'+m for m in re.findall(r'\bSettlementSystem\.([_a-z]\w*)\(',code)]
            elif name=='create_with_cohort_into':
                require('reset.call(outcome)' in code,'typed callback lifetime')
                row['calls'].append('UI._reset_for_create_into')
            row['calls']=sorted(set(row['calls']))
            own[key]=row
    require(sum(row['allocations'] for row in own.values())==3,'only three exclusive outcome construction sites')
    require(sources['UI'].count('ResetOutcome.new()')==2 and sources['Form'].count('ResetOutcome.new()')==1,'no hidden outcome owner')
    frames.update(own)
    for row in frames.values():
        row['calls']=[k for k in row['calls'] if k in frames]
        row.setdefault('allocations',0)
    reachable=set()
    def visit(key):
        if key in reachable:return
        reachable.add(key)
        for child in frames[key]['calls']: visit(child)
    visit('UI.create_world')
    selected={k:frames[k] for k in sorted(reachable)}
    numeric,chain=H.K.longest(selected,'numeric_and_name_bytes')
    references,ref_chain=H.K.longest(selected,'reference_values')
    peak_objects,object_chain=H.K.longest(selected,'allocations')
    require(peak_objects==1,'outcome frames must not overlap')
    retained=1+1+8+8
    packet=sum(H.WIDTH[t] for t in outcome.values())
    constants=3*8+8 # Three integer states and one new named protocol refusal.
    controls=base['accounting']['control_provisional_bytes']+retained+packet+constants+256
    helpers=numeric+references*32+256
    require(controls<=6144 and helpers<=2048,'existing retirement carve-out exceeded')
    for row in selected.values():
        row.pop('body',None);row.pop('values',None)
    return {'scope':'bounded presentation reset caller over accepted actual host; no runtime/native activation claim',
      'source_sha256':{FILES[k]:digest(v.encode()) for k,v in sources.items()},
      'retained_numeric_name_delta':retained,'outcome_numeric_name_bytes':packet,'new_numeric_name_constants':constants,
      'maximum_simultaneous_outcome_objects':peak_objects,'object_chain':object_chain,
      'maximum_numeric_name_bytes':numeric,'numeric_chain':chain,'maximum_reference_values':references,'reference_chain':ref_chain,
      'frames':selected,'packed_bank_delta':0,
      'accounting':{'retirement_reserved_bytes':8192,'controls':controls,'control_ceiling':6144,
       'helpers':helpers,'helper_ceiling':2048,'original_session_reserved_bytes':1536,
       'profile_joint_unchanged':246868,'profile_ceiling':262144,
       'reference_bytes_assumed':32,'one_outcome_header_assumed':256,'expression_allowance':256},
      'existing_boundaries':['Unchanged private UI item catalog and World generation allocations keep their original lifetime/budgets.',
        'Seed/cohort/publish and starter colony/economy helpers keep their original owner reservations.',
        'Existing bounded HUD notice storage and String formatting are presentation-native costs, not simulation arrays.',
        'Complete accepted1158 static retirement stack is included; its existing source/clear-store boundaries are unchanged.'],
      'native_measured':False,'runtime_qualified':False}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
    result=build()
    if args.out.exists() or args.out.is_symlink():raise ValueError('create-only census output')
    args.out.write_text(json.dumps(result,indent=2)+'\n')
