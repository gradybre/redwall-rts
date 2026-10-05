#!/usr/bin/env python3
"""1165 source-pinned logical itinerary lifetime; no native-memory qualification."""
from __future__ import annotations
import argparse
import ast
import hashlib
from importlib.machinery import SourceFileLoader
import importlib.util
import json
from pathlib import Path
import re
import textwrap

ROOT = Path(__file__).resolve().parents[4]
E = Path(__file__).resolve().parent
WIDTH = {'int': 8, 'bool': 1, 'Vector2i': 8, 'Vector3i': 12}
I = 'underground_room_itinerary'
W = 'underground_world_routes'
R = 'underground_routes'
P = 'underground_room_world_bindings'
F = 'underground_room_frontier'
NATIVE = {'get_ref', 'get_script', 'get_instance_id', 'size', 'fill', 'unicode_at', 'is_empty'}
BUILTINS = {'Vector2i', 'Vector3i', 'abs', 'absi', 'mini', 'maxi', 'int', 'str', 'range', 'min', 'max'}
SYNTAX = {'if', 'elif', 'else', 'and', 'or', 'return', 'warning_ignore', 'match'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def executable(source):
    source = re.sub(r'""".*?"""', '', source, flags=re.S)
    return re.sub(r'#.*', '', source)


def path(module):
    if module == I:
        return E / 'itinerary-source.gd.txt'
    if module in ('source_program', 'mole_profile_driver'):
        return ROOT / 'godot/data/underground/mole-worker' / ('work-approach-v1/source_program.gd'
            if module == 'source_program' else 'mole_profile_driver.gd')
    return ROOT / 'godot/scripts/core' / (module + '.gd')


class Audit:
    def __init__(self, overrides=None):
        self.overrides = overrides or {}
        self.sources = {}
        self.scopes = {}
        self.functions = {}
        self.edges = {}
        self.native = {}
        self.unresolved = {}

    def load(self, module):
        if module in self.sources:
            return
        snapshot = E / (module + '.gd.txt')
        source = self.overrides.get(module, (snapshot if snapshot.exists() else path(module)).read_text())
        self.sources[module] = source
        aliases = {name: Path(rel).stem for name, rel in re.findall(
            r'^const (\w+)\s*:?= preload\("res://([^"\n]+)"\)', source, re.M)}
        self._scope(module, module, source, aliases)
        for hit in re.finditer(r'^class (\w+)(?: extends [\w.]+)?:\n', source, re.M):
            lines = []
            for line in source[hit.end():].splitlines():
                if line.strip() and not line.startswith((' ', '\t')):
                    break
                lines.append(line)
            self._scope(module, module + '.' + hit[1], textwrap.dedent('\n'.join(lines)), aliases)

    def _scope(self, module, scope, source, aliases):
        members = dict(re.findall(r'^var (\w+): ([\w.]+)', source, re.M))
        self.scopes[scope] = {'module': module, 'aliases': aliases, 'members': members}
        lines = source.splitlines()
        for start, line in enumerate(lines):
            hit = re.match(r'^(?:static )?func (\w+)\(', line)
            if not hit:
                continue
            end = start + 1
            while end < len(lines) and (not lines[end].strip() or lines[end].startswith(('\t', ' ', ')'))):
                end += 1
            body = executable('\n'.join(lines[start:end]))
            sig = re.match(r'^(?:static )?func \w+\((.*?)\)\s*(?:->\s*([^:\n]+))?:', body, re.S)
            require(sig is not None, 'unparsed signature ' + hit[1])
            signature, code = sig[1], body[sig.end():]
            fields = re.findall(r'(\w+)\s*:\s*([\w.]+)', signature)
            fields += re.findall(r'\b(?:var|for) (\w+)\s*:\s*([\w.]+)', code)
            key = scope + ':' + hit[1]
            require(key not in self.functions, 'duplicate function ' + key)
            self.functions[key] = {
                'scope': scope, 'module': module, 'name': hit[1], 'body': body, 'code': code,
                'types': dict(fields), 'numeric_fields': [(n, k) for n, k in fields if k in WIDTH],
                'numeric_bytes': sum(WIDTH.get(k, 0) for n, k in fields),
                'borrowed_or_interned': [(n, k) for n, k in fields if k not in WIDTH],
            }

    def canonical(self, scope, typename):
        info = self.scopes[scope]
        parts = typename.split('.')
        if parts[0] in info['aliases']:
            return '.'.join([info['aliases'][parts[0]], *parts[1:]])
        own = info['module'] + '.' + typename
        return own if own in self.scopes else typename

    def method(self, key, expression):
        fn = self.functions[key]
        scope = fn['scope']
        if '.' not in expression:
            target = scope + ':' + expression
            return target if target in self.functions else None
        parts = expression.split('.')
        base, attrs, method = parts[0], parts[1:-1], parts[-1]
        if base in ('self',):
            receiver = scope
        elif base in self.scopes[scope]['aliases']:
            receiver = self.scopes[scope]['aliases'][base]
        elif self.scopes[scope]['module'] + '.' + base in self.scopes:
            receiver = self.scopes[scope]['module'] + '.' + base
        else:
            typename = fn['types'].get(base, self.scopes[scope]['members'].get(base))
            if typename is None:
                return None
            if typename == 'RefCounted':
                if base == 'actual':
                    typename = scope
                elif base == 'certificate':
                    typename = W
                elif base == 'bank' and fn['name'] == '_committed_mask_refusal':
                    typename = W + '.Certificates'
            receiver = self.canonical(scope, typename)
        for attr in attrs:
            module = receiver.split('.')[0]
            if path(module).exists() or module in self.overrides:
                self.load(module)
            nested = receiver + '.' + attr
            if nested in self.scopes:
                receiver = nested
                continue
            if receiver not in self.scopes:
                return None
            typename = self.scopes[receiver]['members'].get(attr)
            if typename is None:
                return None
            receiver = self.canonical(receiver, typename)
        module = receiver.split('.')[0]
        if path(module).exists() or module in self.overrides:
            self.load(module)
        target = receiver + ':' + method
        return target if target in self.functions else None

    def visit(self, key):
        self.load(key.split(':')[0].split('.')[0])
        require(key in self.functions, 'unknown function ' + key)
        if key in self.edges:
            return
        edges, native, unresolved = set(), set(), set()
        code = self.functions[key]['code']
        if key == R + ':_path_profile_refusal':
            # Both measured static callers pass their actual non-null certificate.
            # Preserve the full declared frame, but do not splice the mutually
            # exclusive actor/profile observation branch into this call lifetime.
            first = '\n\tif certificate != null:\n\t\treturn _committed_mask_refusal(row, certificate)'
            require(code.lstrip().startswith(first.lstrip()), 'certificate branch ordering')
            code = first
        for call in re.findall(r'(?<![\w.])([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*\(', code):
            target = self.method(key, call)
            if target:
                edges.add(target)
            elif call in SYNTAX:
                continue
            elif call.rsplit('.', 1)[-1] in NATIVE or call in BUILTINS:
                native.add(call)
            else:
                unresolved.add(call)
        self.edges[key] = sorted(edges)
        self.native[key] = sorted(native)
        self.unresolved[key] = sorted(unresolved)
        for target in sorted(edges):
            self.visit(target)

    def longest(self, key, stack=()):
        require(key not in stack, 'recursive helper ' + key)
        children = [self.longest(c, stack + (key,)) for c in self.edges[key]]
        below = max(children, key=lambda c: (c['bytes'], c['chain'])) if children else {'bytes': 0, 'chain': []}
        return {'bytes': self.functions[key]['numeric_bytes'] + below['bytes'], 'chain': [key] + below['chain']}


# Publication uses only this bounded call closure. Native queries are listed in
# the output; their object/Variant/stack layout is not measured by this script.
def packet(a, module, name):
    a.load(module)
    return sum(WIDTH.get(t, 0) for t in a.scopes[module + '.' + name]['members'].values())


def own_graph(a, module):
    a.load(module)
    found = {k:v for k,v in a.functions.items() if k.startswith(module + ':')}
    edges = {k:sorted({module + ':' + child for child in re.findall(
        r'(?<![\w.])(\w+)\s*\(', v['code']) if module + ':' + child in found}) for k,v in found.items()}
    return found, edges


def own_peak(a, module, end=None):
    found, edges = own_graph(a, module)
    def walk(key, stack=()):
        require(key not in stack, 'recursive caller ' + key)
        if end is not None and key == module + ':' + end:
            return [{'bytes':found[key]['numeric_bytes'], 'chain':[key]}]
        below = [item for child in edges[key] for item in walk(child, stack + (key,))]
        if not below and end is None:
            below = [{'bytes':0, 'chain':[]}]
        return [{'bytes':found[key]['numeric_bytes'] + item['bytes'], 'chain':[key]+item['chain']} for item in below]
    chains = [item for key in found for item in walk(key)]
    require(bool(chains), 'missing caller target ' + str(end))
    return max(chains, key=lambda x:(x['bytes'],x['chain']))


def constants(source):
    result = {}
    for name, typ, value in re.findall(r'^const (\w+): (\w+) = ([^\n]+)', source, re.M):
        if typ in WIDTH:
            result[name] = WIDTH[typ]
        elif typ in ('String', 'StringName'):
            match = re.fullmatch(r'&?"([^"\n]*)"', value.strip())
            require(match is not None, 'nonliteral string payload ' + name)
            # Count UTF32 characters and a trailing NUL conservatively. Native
            # StringName/Script intern tables remain in the provisional remainder.
            result[name] = (len(match[1]) + 1) * 4
        else:
            raise ValueError('unaccounted constant ' + name + ':' + typ)
    return result


def frame_summary(a, key):
    fn = a.functions[key]
    return {k:fn[k] for k in ('numeric_bytes','numeric_fields','borrowed_or_interned')}


def load_paths(relative):
    pin=json.loads((E/'predecessor-sha256.json').read_text())['turn_paths']
    require(pin['source'] == 'docs/validation/evidence/'+relative, 'wrong predecessor producer')
    file=E/pin['snapshot']
    data=file.read_bytes()
    require(pin['sha256'] == hashlib.sha256(data).hexdigest(), 'reviewed predecessor witness changed')
    imports=[]
    for node in ast.walk(ast.parse(data)):
        if isinstance(node,ast.Import): imports.extend(n.name for n in node.names)
        if isinstance(node,ast.ImportFrom): imports.append(node.module)
    require(sorted(set(imports)) == pin['imports'] == ['hashlib','json','pathlib','re'],
            'unreviewed predecessor import closure')
    loader=SourceFileLoader('reviewed_turn_path_witness',str(file))
    spec = importlib.util.spec_from_loader(loader.name,loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.PATHS


def predecessor(module):
    pin=json.loads((E/'predecessor-sha256.json').read_text())[module]
    data=(E/pin['snapshot']).read_bytes()
    require(hashlib.sha256(data).hexdigest() == pin['sha256'], 'caller predecessor witness changed')
    return data.decode()


def build(overrides=None):
    a = Audit(overrides)
    entry = I + ':reachability_refusal'
    a.visit(entry)
    require(not any(a.unresolved.values()), 'unresolved source call ' + str({k:v for k,v in a.unresolved.items() if v}))
    itinerary_edges = dict(a.edges)
    itinerary_native = dict(a.native)
    require(a.sources[I].startswith('extends RefCounted\n'), 'itinerary inherited state')
    require(not re.search(r'^var\b|^class\b', a.sources[I], re.M), 'retained itinerary fields/classes')
    require(not re.search(r'Packed\w+Array\s*\(|\b(?:Array|Dictionary)\s*\(|\.(?:new|resize|duplicate|append|append_array|to_utf8_buffer|hex_decode)\s*\(', executable(a.sources[I])), 'itinerary allocation')
    require(set(constants(a.sources[I])) == {'NULL_REF','REFUSE_FAMILY'}, 'itinerary constant topology')
    require('locations._ids.get_script() != Directory' in a.functions[I+':_implementations']['code'], 'concrete final Directory guard')
    require('actual._witness_serial = 0' in a.functions[entry]['code'], 'stale search witness')
    busy = a.functions[W+':_reach_entry_refusal']['code']
    for term in ('actual._reading','actual._opening','actual._compiling','actual._publishing','actual._route_token',
                 'graph._searching','graph._advancing','graph._occupancy_reading','graph._token',
                 'locations._token','locations._in_retention','owner._stage_token','owner._room_callback'):
        require(term in busy, 'lost sequential lifetime guard ' + term)
    itinerary = a.longest(entry)
    require(itinerary['bytes'] + 48 <= 512, 'itinerary helper reservation')
    program=a.sources['source_program']
    program_ints=re.findall(r'^const \w+: int = [^\n]+$',program,re.M)
    program_strings=re.findall(r'^const \w+: String = "([^"\n]*)"$',program,re.M)
    shared_program_bytes=8*len(program_ints)+4*sum(map(len,program_strings))
    require(shared_program_bytes == 640 and not re.search(r'^var\b|^class\b',program,re.M),
            'shared SourceProgram payload drift')
    for key in itinerary_edges:
        fn = a.functions[key]
        require(not re.search(r'\b(?:var|for) \w+\s*(?::=|=)', fn['code']), 'untyped helper local '+key)
        require(not any(t in ('float','Vector2','Vector3','Variant','Array','Dictionary')
                        for _,t in fn['borrowed_or_interned']), 'unaccounted helper value '+key)
    # Existing single-profile search and workpiece physical occupancy use the
    # same fixed owner storage on mutually exclusive synchronous calls.
    a.visit(W+':profile_reachability_refusal')
    for key, invocation in {
        W+':_reach_path':'graph._find_path(first, last, actual._descriptor.mode, actual._descriptor.posture, null, actual)',
        R+':_find_path':'_relax_edges(Vector2i(node, generation), mode, posture, query, certificate)',
        R+':_relax_edges':'_path_profile_refusal(row, query, certificate)',
    }.items():
        require(invocation in a.functions[key]['code'], 'static certificate propagation '+key)
    route = a.longest(W+':profile_reachability_refusal')
    a.visit(W+':workpiece_occupancy_refusal')
    occupancy = a.longest(W+':workpiece_occupancy_refusal')
    # Preserve the reviewed current observed-turn chains, and independently trace
    # the complete final/clock branches added since their original evidence.
    turn_paths = load_paths('underground-ground-turn-2026-10-04/census.py')
    turn = {}
    for label, chain in turn_paths.items():
        for key in chain:
            a.load(key.split(':')[0])
        turn[label] = {'chain':chain, 'bytes':sum(a.functions[k]['numeric_bytes'] for k in chain), 'allowance':48}
    a.visit(W+':_turn_final')
    final = a.longest(W+':_turn_final')
    prefix = [W+':turn_actor', W+':_turn_run']
    final = {'chain':prefix+final['chain'], 'bytes':sum(a.functions[k]['numeric_bytes'] for k in prefix)+final['bytes'], 'allowance':48}
    a.visit(W+':_turn_actor_scope')
    clock = a.longest(W+':_turn_actor_scope')
    clock = {'chain':prefix+clock['chain'], 'bytes':sum(a.functions[k]['numeric_bytes'] for k in prefix)+clock['bytes'], 'allowance':48}
    turns = {**turn, 'complete_current_final':final, 'current_source_clock':clock}
    require(max(v['bytes']+48 for v in turns.values()) <= 512, 'existing turn helper grew')
    require(route['bytes']+48 <= 512 and occupancy['bytes']+48 <= 512, 'existing route/occupancy helper grew')
    # Any new transitive native operation requires explicit classification rather
    # than disappearing from a regex's unknown-method path.
    permitted_existing = {'Residents.SPECIES_RIG_KEY.has','residents._rig_ids.has','StringName','_resource_ids.find','String'}
    unknown = {k:v for k,v in a.unresolved.items() if set(v)-permitted_existing}
    require(not unknown, 'unknown existing helper calls ' + str(unknown))
    # The two caller changes are exactly dispatch changes, not silently widened
    # retained packets. Compare every original function except the path method.
    callers = {}
    for module, end in ((P,'_ordinary_path'),(F,'_path')):
        a.load(module)
        base = Audit({module:predecessor(module)});base.load(module)
        require(a.scopes[module]['members'] == base.scopes[module]['members'], 'caller retained member drift ' + module)
        require(re.findall(r'^extends .+$',a.sources[module],re.M) == re.findall(r'^extends .+$',base.sources[module],re.M), 'caller base drift')
        current = {k:v['body'] for k,v in a.functions.items() if k.startswith(module+':') and k != module+':'+end}
        previous = {k:v['body'] for k,v in base.functions.items() if k.startswith(module+':') and k != module+':'+end}
        require(current == previous, 'unreviewed caller function change ' + module)
        require('Itinerary.reachability_refusal(' in a.functions[module+':'+end]['code'], 'missing itinerary dispatch')
        require('POLICY_AUTOMATIC' in a.functions[module+':'+end]['code'], 'automatic path distinction')
        callers[module] = {'active_prefix':own_peak(a,module,end),'maximum_own_chain':own_peak(a,module)}
    provider_fixed = sum(WIDTH.get(t,0) for t in a.scopes[P]['members'].values()) + packet(a,'underground_work_face','Request') + 4
    require(provider_fixed == 218, 'provider fixed packet drift')
    require(callers[P]['maximum_own_chain']['bytes']+64+40 <= 512, 'provider local helper envelope')
    require(provider_fixed+512+256 == 986 <= 1024, 'provider reservation')
    for module in (P,F):
        c=callers[module]
        c['complete_itinerary_declared_bytes']=c['active_prefix']['bytes']+itinerary['bytes']
        c['itinerary_counted_once_in_world_routes_helper']=True
    # Frontier's already admitted complete foreign-helper bound remains valid.
    frontier_fixed = packet(a,F,'Candidate')*2 + packet(a,F,'Query') + 2*packet(a,'underground_work_face','Request') + 4
    require(frontier_fixed == 430, 'frontier packet drift')
    frontier_bound = callers[F]['maximum_own_chain']['bytes'] + 512 + 128
    require(frontier_bound <= 1024 and frontier_fixed+1024+512 == 1966 <= 2048, 'frontier cold reservation')
    fixed = {
        'owner_numeric':sum(WIDTH.get(t,0) for t in a.scopes[W]['members'].values()),
        'Domain_numeric':packet(a,'room_space','Domain'),
        'Descriptor_numeric':packet(a,'underground_profiles','Descriptor'),
        'two_Profile_Box_numeric':2*packet(a,'underground_profiles','Box'),
        'Location_Record_numeric':packet(a,'underground_locations','Record'),
        'Region_numeric':packet(a,'underground_space_owner','Region'),
        'Edge_numeric':packet(a,R,'Edge'),
        'IntResult_numeric':packet(a,'int_math','IntResult'),
    }
    scratch = re.findall(r'([\w.]+)\.resize\((\d+)\)', a.functions[W+':_allocate_scratch']['code'])
    require(scratch == [('_bounds','6'),('_support','6'),('_scratch','6'),('_first_point','3'),('_last_point','3'),('_endpoint.envelope','6'),('_endpoint.support','6'),('_section.box','6')], 'fixed WorldRoutes scratch changed')
    fixed['packed_scratch_and_Domain_bounds'] = 4*(sum(int(n) for _,n in scratch)+6)
    require(sum(fixed.values()) == 958, 'WorldRoutes retained numeric drift')
    topology = json.loads((E/'storage-topology.json').read_text())
    for scope, wanted in topology.items():
        a.load(scope.split('.')[0])
        require(a.scopes[scope]['members'] == wanted, 'retained reference/bank topology '+scope)
    world_constants = constants(a.sources[W]); itinerary_constants = constants(a.sources[I])
    logical = sum(fixed.values())+sum(world_constants.values())+sum(itinerary_constants.values())+512
    require(logical < 4096, 'WorldRoutes control ceiling')
    # Dijkstra storage is already admitted in Routes; read actual member kinds and
    # resize expressions so a second/capacity-growing scratch cannot hide here.
    arrays={'_distance':('PackedInt64Array',8,1),'_predecessor':('PackedInt32Array',4,1),
            '_heap_node':('PackedInt32Array',4,1),'_heap_position':('PackedInt32Array',4,1),
            '_search_state':('PackedByteArray',1,1),'_proposed_edges':('PackedInt32Array',4,2)}
    for name,(typ,_,mul) in arrays.items():
        require(a.scopes[R]['members'].get(name)==typ, 'route scratch type '+name)
        expected='_location_capacity' if mul==1 else '2 * _location_capacity'
        require(re.findall(r'\b'+name+r'\.resize\(([^\n]*)\)', a.sources[R])==[expected], 'route scratch allocation '+name)
    new_frames={key:frame_summary(a,key) for key in sorted(itinerary_edges)}
    all_frames={key:frame_summary(a,key) for key in sorted(a.edges)}
    selected={key:frame_summary(a,key) for value in turns.values() for key in value['chain']}
    used_sources={m:hashlib.sha256(v.encode()).hexdigest() for m,v in sorted(a.sources.items())}
    return {
        'scope':'Logical declared numeric/packed payload census only; no native allocation or runtime qualification.',
        'source_sha256':used_sources,
        'itinerary':{'retained_fields':{},'new_banks':0,'new_array_bytes':0,'new_actor_columns':0,
            'reachable_functions':len(itinerary_edges),'peak':itinerary,'expression_return_allowance':48,
            'inclusive_peak':itinerary['bytes']+48,'helper_reserve':512,'call_graph':itinerary_edges,
            'native_queries':itinerary_native,'frames':new_frames},
        'world_routes_controls':{'fixed':fixed,'fixed_sum':sum(fixed.values()),
            'existing_constant_payloads':world_constants,'new_itinerary_constant_payloads':itinerary_constants,
            'one_sequential_helper_reserve':512,'logical_subtotal':logical,'unchanged_control_reserve':4096,
            'remaining_provisional_native_reference_bytes':4096-logical,
            'native_measured':False},
        'callers':callers,
        'provider':{'retained_numeric_payload':provider_fixed,'existing_helper':512,'included_provisional_native':256,
            'accounted':986,'reserve':1024,'existing_non_itinerary_complete_helper_evidence':485},
        'frontier':{'caller_and_private_packet_payload':frontier_fixed,'existing_complete_helper':1024,
            'current_complete_helper_bound':frontier_bound,'included_provisional_native':512,
            'accounted':1966,'cold_reserve':2048,'existing_work_face_peak':378880,'total_existing_cold_peak':380928},
        'nonoverlapping_existing_helpers':{'single_profile_search':route,'physical_occupancy':occupancy,'turns':turns,
            'allowance':48,'all_resident_source_admission_and_tick_helpers':'The separate existing1156 Profile control slice owns its632B complete dynamic source chain; no copy or extra charge here.'},
        'static_certificate_specialization':'Both static entries pass the actual non-null WorldRoutes certificate through _find_path and _relax_edges. The complete declared _path_profile_refusal frame is counted, but only its first committed-mask branch is reachable. Propagation and branch ordering are checked from source; the separate dynamic actor branch is not silently added or omitted from an eligible lifetime.',
        'reused_storage':{'Dijkstra_arrays':{n:{'type':t,'bytes_per_location':w*m} for n,(t,w,m) in arrays.items()},
            'Dijkstra_1024_locations_bytes':sum(w*m for t,w,m in arrays.values())*1024,
            'WorldRoutes_two_certificate_banks_bytes':2*1536*(32+4+16),
            'new_Profile_Descriptor':False,'new_Result':False,'new_Path':False,'new_Selection':False,
            'caller_remaining_i32_bytes':4,'caller_remaining_counted_in_existing_packets':True,
            'SourceProgram_constants_shared_once_under_Profile_controls':shared_program_bytes,
            'inherited_entry_binding_reserve_unchanged_not_part_of_new_Provider_1024':2048,
            'shared_PhaseContext_bytes_already_in_Placement':128},
        'other_current_frames':{**all_frames,**selected},
        'lifetime':'Itinerary enters only with no graph search/advance/occupancy/candidate and no WorldRoutes read/compile/publication. The complete proof is synchronous; old one-profile witness is invalidated. Provider and Frontier caller frames coexist and are partitioned to their original slices; graph and occupancy stacks are alternatives, not added. No cold snapshot/WorkFace is created by the itinerary. Existing Frontier2048 cold admission remains conservative and unchanged.',
        'limits':['Native object/Variant/Script/StringName headers and interpreter stack are provisional, not measured.',
            'Constants count UTF32 payload plus NUL; Script preload references borrow already loaded modules.',
            'The two existing bank images and Dijkstra scratch are reused, never reserved a second time.',
            'No runtime READY, movement, capacity increase or hardware performance qualification follows.'],
    }


def main():
    global ROOT
    parser=argparse.ArgumentParser()
    parser.add_argument('--verify-pins',action='store_true')
    parser.add_argument('--runtime-root',type=Path,help='Read an accepted runtime checkout without changing it; the three frozen reviewed snapshots stay local.')
    args=parser.parse_args()
    if args.runtime_root is not None:
        ROOT=args.runtime_root.resolve()
    result=build()
    if args.verify_pins:
        wanted=json.loads((E/'source-sha256.json').read_text())
        require(result['source_sha256']==wanted,'source pins changed')
    print(json.dumps(result,indent=2))


if __name__ == '__main__':
    main()
