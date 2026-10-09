#!/usr/bin/env python3
"""1163 composed logical lifecycle census; no native allocator or gameplay qualification."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import constructor_census

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
MANIFEST_SHA = '1ec68c33dde42e478c9e4c38dff0599ca60063c23eb379d417773d481629de1d'
FILES = {'Session':'godot/scripts/core/underground_session.gd',
         'Retirement':'godot/scripts/core/underground_world_retirement.gd',
         'Host':'godot/scripts/systems/settlement_system.gd',
         'Composition':'godot/scripts/core/underground_room_composition.gd',
         'RoomCatalog':'godot/scripts/core/room_catalog.gd'}
WIDTH = {'int':8,'bool':1,'Vector2i':8,'Vector3i':12,'StringName':8,'float':8,'void':0}


def require(value, message):
    if not value: raise ValueError(message)


def sha(data): return hashlib.sha256(data).hexdigest()


def predecessor():
    data=(HERE/'predecessor/manifest.json').read_bytes()
    require(sha(data)==MANIFEST_SHA,'immutable predecessor manifest drift')
    rows=json.loads(data);out={}
    for name,row in rows.items():
        value=(ROOT/row['locator']).read_bytes()
        require(sha(value)==row['sha256'],'immutable predecessor source drift '+name)
        out[name]=value.decode()
    return out


def members(source):
    pairs=re.findall(r'^var (\w+): ([\w.]+)',source,re.M)
    require(len(pairs)==len(re.findall(r'^var ',source,re.M)),'typed module fields')
    return dict(pairs)


def class_members(source,name):
    value=source.split('class '+name+' extends RefCounted:\n',1)[1]
    value=re.split(r'^\S',value,maxsplit=1,flags=re.M)[0]
    pairs=re.findall(r'^\tvar (\w+): ([\w.]+)',value,re.M)
    require(len(pairs)==len(re.findall(r'^\tvar ',value,re.M)),'typed class fields')
    return dict(pairs)


def parse(source,module):
    result={}
    for match in re.finditer(r'^(static )?func (\w+)\((.*?)\) -> ([\w.]+):\n(.*?)(?=^(?:static )?func |\Z)',source,re.M|re.S):
        static,name,parameters,returns,body=match.groups()
        params=re.findall(r'(\w+):\s*([\w.]+)',parameters)
        local=re.findall(r'^\s*(?:@[^\n]* )?var (\w+):\s*([\w.]+)',body,re.M)
        require(len(params)==parameters.count(':'),'untyped arguments '+name)
        require(len(local)==len(re.findall(r'^\s*(?:@[^\n]* )?var ',body,re.M)),'untyped locals '+name)
        values=params+local
        code=re.sub(r'""".*?"""|#[^\n]*','',body,flags=re.S)
        calls=[module+'.'+x for x in re.findall(r'(?<![.\w])([_a-zA-Z]\w*)\(',code)]
        calls += [receiver+'.'+method for receiver,method in re.findall(r'\b(Retirement|Composition|Buildings|Construction|Work|Inventory)\.([a-z_]\w*)\(',code)]
        if module=='Host': calls += ['Session.'+x for x in re.findall(r'\b(?:original|_underground_session)\.([a-z_]\w*)\(',code)]
        if module=='Composition': calls += ['Session.'+x for x in re.findall(r'\bsession\.([a-z_]\w*)\(',code)]
        result[module+'.'+name]={'numeric_and_name_bytes':sum(WIDTH.get(t,0) for _,t in values)+WIDTH.get(returns,0),
          'reference_values':sum(t not in WIDTH for _,t in values)+int(static is None)+int(returns not in WIDTH),
          'calls':sorted(set(calls)),'values':values,'body':body,'returns':returns}
    return result


def reachable(frames, roots):
    found=set()
    def visit(key):
        require(key in frames,'missing call frame '+key)
        if key in found:return
        found.add(key)
        for child in frames[key]['calls']:
            if child in frames:visit(child)
    for key in roots:visit(key)
    return {key:dict(frames[key],calls=[c for c in frames[key]['calls'] if c in found]) for key in sorted(found)}


def longest(frames, metric):
    def visit(key,active):
        require(key not in active,'recursive lifetime '+key)
        value,chain=max((visit(child,active+[key]) for child in frames[key]['calls']),default=(0,[]),key=lambda r:r[0])
        return frames[key][metric]+value,[key]+chain
    return max((visit(key,[]) for key in frames),key=lambda r:r[0])


def peak(frames,roots):
    selected=reachable(frames,roots)
    numeric,nchain=longest(selected,'numeric_and_name_bytes')
    refs,rchain=longest(selected,'reference_values')
    return {'numeric_bytes':numeric,'reference_values':refs,'numeric_chain':nchain,'reference_chain':rchain,
            'provisional_bytes':numeric+refs*32+256,'frames':selected}


def build(replacements=None, constructor_replacements=None):
    old=predecessor(); sources={k:(ROOT/v).read_text() for k,v in FILES.items()};sources.update(replacements or {})
    pack=json.loads(old['docs/planning/underground_memory_pack.json'])
    base=pack['ui_reset_reservation']; before=pack['host_retirement_reservation']
    for module in ('Session','Host'):
        a,b=members(old[FILES[module]]),members(sources[module])
        require({k:v for k,v in b.items() if k not in a}==
          ({'_operations_state':'int','_operations_prefix':'int'} if module=='Session' else {}),'exact retained composition state')
        require(all(b.get(k)==v for k,v in a.items()),'original member types')
    for klass in ('Owners','Scope'):
        a,b=class_members(old[FILES['Retirement']],klass),class_members(sources['Retirement'],klass)
        require({k:v for k,v in b.items() if k not in a}==({'_constructor_prefix':'int'} if klass=='Scope' else {}),'fixed private Scope/Owners')
        require(all(b.get(k)==v for k,v in a.items()),'original tuple types')
    require(not members(sources['Composition']) and not re.search(r'^static var ',sources['Composition'],re.M),'stateless composer')
    require(sources['Session'].count('Retirement.Owners.new()')==1 and sources['Session'].count('Retirement.Scope.new()')==1,'one permanent packet and one Scope')
    require(sources['Retirement'].count('Owners.new()')==1,'one private fixed Scope copy')
    require(members(sources['RoomCatalog'])=={'_definitions':'BuildingDefinitions'},'one borrowed catalog reference')
    require('var _definitions: BuildingDefinitions = null' in sources['RoomCatalog'],'no eager duplicate catalog')
    require('RoomCatalog.new(o.buildings._definitions)' in sources['Composition'] and
      sources['Composition'].count('RoomCatalog.new(')==1,'borrow original catalog at construction')
    require(sorted(re.findall(r'\b([A-Z][\w.]*)\.new\(',sources['Composition']))==sorted([
      'Provider','Authority','Sites','Router','RoomBindings','Orders','RoomCatalog','Locations',
      'Locations.InventoryLocations']),'exact constructor owner multiplicity')
    for expression in ('Funding.MAX_RECEIPT_CAPACITY, Sites.MAX_SITE_CAPACITY)',
      'o.space, o.world_bindings, Budget.PROOF_CAPACITY)',
      'o.budget, Budget.LOCATION_CAPACITY, 228 * Budget.LOCATION_CAPACITY + 256)',
      'Budget.INVENTORY_ENDPOINT_CAPACITY)'):
        require(expression in sources['Composition'],'original admitted constructor capacities')
    require('_definitions = definitions if definitions != null else BuildingDefinitions.new()' in sources['RoomCatalog'],
      'optional borrowed constructor preserves standalone default')
    require('o.rooms._catalog._definitions != o.buildings._definitions' in sources['Retirement'] and
      'Retirement.constructor_catalog_refusal(o)' in sources['Composition'] and
      'o.rooms != null and constructor_catalog_refusal(o)' in sources['Retirement'],'full and prefix catalog identity')
    require('if code == &"" and o.buildings._definitions == null: code = &"UNDERGROUND_COMPOSITION_CATALOG"'
      in sources['Composition'],'null source cannot trigger standalone catalog fallback')
    frames={k:dict(v) for k,v in before['frames'].items()}
    frames.update({k:dict(v) for k,v in base['frames'].items()})
    own={}
    for k,v in sources.items():own.update(parse(v,k))
    compose=own['Session.compose_room_owners']['body']
    current=own['Session._current_refusal']['body']
    prepare=own['Session.prepare_retirement']['body']
    require(compose.index('current_refusal()') < compose.index('_busy = true') <
      compose.index('Composition.construct(self)') < compose.index('_busy = false'),'exclusive constructor bracket')
    require(re.search(r'if _retirement_scope != null:\n\s+return &"UNDERGROUND_SESSION_RETIRING"',current),
      'no existing Scope during constructor')
    require(re.search(r'if _busy or not _ready:\n\s+return &"UNDERGROUND_SESSION_UNAVAILABLE"',prepare),
      'no reentrant Scope allocation')
    require('Retirement.Scope.new()' not in compose and 'Retirement.Owners.new()' not in compose,
      'constructor does not create another lifetime packet')
    frames.update(own)
    roots=['Host.reset','Host.prepare_world_reset','Host.abandon_world_reset','Host._notification',
           'Session._build_retirement_owners','UI.create_world','Host.compose_underground_room_owners']
    all_frames=reachable(frames,roots)
    for key,row in all_frames.items():
        if key not in own:continue
        require(all(t not in ('Variant','Array','Dictionary') and not t.startswith('Packed') for _,t in row['values']),'variable helper '+key)
        code=re.sub(r'""".*?"""|#[^\n]*','',row['body'],flags=re.S)
        require(not re.search(r'\bfor |\.duplicate\(|\.resize\(',code),'unbounded helper '+key)
    results={label:peak(frames,rs) for label,rs in {
       'reset_with_ui':['UI.create_world'],
       'direct_reset':['Host.reset','Host.prepare_world_reset','Host.abandon_world_reset','Host._notification'],
       'composition_own_prefix':['Host.compose_underground_room_owners']}.items()}
    for result in results.values():
        for row in result['frames'].values():row.pop('body',None);row.pop('values',None)
    controls=base['accounting']['controls']+24
    helpers=max(r['provisional_bytes'] for r in results.values())
    require(controls<=6144 and helpers<=2048,'complete reset/UI envelope exceeded')
    constructor=constructor_census.build(sources,constructor_replacements)
    absent=[class_members(sources['Retirement'],k) for k in ('Scope','Owners')]
    absent_numeric=sum(WIDTH.get(t,0) for m in absent for t in m.values())
    absent_references=sum(t not in WIDTH for m in absent for t in m.values())
    absent_bytes=absent_numeric+absent_references*32+2*256
    constructor_controls=controls-absent_bytes
    constructor_total=constructor_controls+constructor['maximum_provisional_bytes']
    require(constructor_total<=8192,'constructor simultaneous peak exceeds original retirement reservation')
    return {'source_sha256':{FILES[k]:sha(v.encode()) for k,v in sources.items()},'baseline_commit':'ebdd5daa2b723a63dd71e2018d2bed9b279cf894',
       'retained_numeric_delta':24,'retained_reference_delta':0,'additional_packed_bytes':0,
       'phases':results,'constructor':constructor,
       'constructor_exclusive_reuse':{'absent_numeric_bytes':absent_numeric,'absent_reference_values':absent_references,
         'absent_two_object_headers':512,'absent_total':absent_bytes,'remaining_controls':constructor_controls,
         'constructor_stack_and_heap':constructor['maximum_provisional_bytes'],'simultaneous_total':constructor_total,
         'ceiling':8192,'remaining':8192-constructor_total},
       'accounting':{'controls':controls,'control_ceiling':6144,'helpers':helpers,'helper_ceiling':2048,
         'retirement_reserved_bytes':8192,'existing_session_reserved_bytes':1536,'profile_joint':246868,'profile_ceiling':262144},
       'native_measured':False,'runtime_qualified':False}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    require(not a.out.exists() and not a.out.is_symlink(),'create-only census')
    a.out.write_text(json.dumps(build(),indent=2)+'\n')
