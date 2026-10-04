#!/usr/bin/env python3
"""Count the complete synchronous retirement tuple and static call graph; no native measurement claim."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
CORE = 'godot/scripts/core/'
FILES = {name: CORE + file + '.gd' for name, file in (
    ('Retirement', 'underground_world_retirement'), ('Buildings', 'buildings'),
    ('Construction', 'construction'), ('Work', 'work'), ('Inventory', 'inventory'),
    ('Session', 'underground_session'))}
WIDTH = {'int': 8, 'bool': 1, 'Vector2i': 8, 'Vector3i': 12, 'StringName': 8}
EXPECTED_OWNERS = ('world_ref world directory buildings construction inventory items residents jobs work '
                   'reservations transforms gear carry piles content budget space sources routes terrain profiles '
                   'levels rooms room_bindings world_bindings sites router authority locations inventory_locations '
                   'world_routes connector contacts placements workpieces delivery furniture tips').split()
EXPECTED_SCOPE = ('_owners _host _session _persistent_id _stage _allow_prepared_world _delivery_script '
                  '_profile_bank _catalog _catalog_bank _movement _prepared_request _prepared_seed _prepared_attempts').split()
ALIAS = {'RetirementBuildings': 'Buildings', 'Buildings': 'Buildings', 'Construction': 'Construction',
         'Work': 'Work', 'Inventory': 'Inventory'}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def fields(text):
    found = re.findall(r'^\s*var (\w+): ([\w.]+)\s*=', text, re.M)
    require(len(found) == len(re.findall(r'^\s*var ', text, re.M)), 'untyped/unsupported field')
    require(len(dict(found)) == len(found), 'duplicate field')
    require(all(not kind.startswith(('Packed', 'Array', 'Dictionary')) for _, kind in found), 'no new bank')
    return found


def functions(text, module, tail_only=False):
    result = {}
    pattern = r'^(static )?func (\w+)\((.*?)\) -> ([\w.]+):\n(.*?)(?=^(?:static )?func |\Z)'
    for match in re.finditer(pattern, text, re.M | re.S):
        static, name, parameters, returns, body = match.groups()
        if tail_only and 'retirement' not in name:
            continue
        require(static is not None, 'retirement helper must be static: ' + module + '.' + name)
        args = re.findall(r'(\w+):\s*([\w.]+)', parameters)
        locals_ = re.findall(r'^\s*(?:@[^\n]* )?var (\w+):\s*([\w.]+)', body, re.M)
        require(len(args) == parameters.count(':'), 'untyped arguments')
        require(len(locals_) == len(re.findall(r'^\s*var ', body, re.M)), 'untyped locals')
        values = args + locals_
        require(all(kind not in ('Variant', 'Array', 'Dictionary') and not kind.startswith('Packed')
                    for _, kind in values), 'variable helper shape')
        require(not re.search(r'\.new\(|\.resize\(|\.duplicate\(|\.slice\(|\b(?:Array|Dictionary|Packed\w+Array)\s*\(', body),
                'allocation inside static retirement chain')
        require(not re.search(r'\b(?:await|emit_signal|call|callv|call_deferred|load)\s*\(', body), 'observer in retirement chain')
        for receiver, method in re.findall(r'\b([\w.]+)\.([a-z_]\w*)\(', body):
            require(receiver in ALIAS or method in {'get_ref', 'get_script', 'has', 'size', 'count'},
                    'non-native observer in retirement chain: ' + receiver + '.' + method)
        calls = []
        for target, function in re.findall(r'\b([A-Z]\w*)\.([a-z_]\w*)\(', body):
            if target in ALIAS:
                calls.append(ALIAS[target] + '.' + function)
        calls += [module + '.' + x for x in re.findall(r'(?<![.\w])([_a-zA-Z]\w*)\(', body)]
        numeric = sum(WIDTH.get(kind, 0) for _, kind in values) + WIDTH.get(returns, 0)
        refs = sum(kind not in WIDTH for _, kind in values)
        result[module + '.' + name] = {'numeric_and_name_bytes': numeric, 'reference_values': refs,
                                      'calls': sorted(set(calls)), 'returns': returns}
    return result


def longest(frames, metric):
    def visit(name, active):
        require(name not in active, 'recursive release chain')
        children = [visit(child, active + [name]) for child in frames[name]['calls']]
        extra, chain = max(children, default=(0, []), key=lambda pair: pair[0])
        return frames[name][metric] + extra, [name] + chain
    return max((visit(name, []) for name in frames), key=lambda pair: pair[0])


def build(root=ROOT, replacements=None):
    sources = {name: (root / path).read_text() for name, path in FILES.items()}
    sources.update(replacements or {})
    source = sources['Retirement']
    require(source.startswith('extends RefCounted\n'), 'unchanged stateless base')
    require(not re.search(r'^var |^static var ', source, re.M), 'no module-retained state')
    require(re.findall(r'^class (\w+)', source, re.M) == ['Owners', 'Scope'], 'fixed caller classes only')
    owners = fields(source.split('class Owners extends RefCounted:\n')[1].split('\n\nclass Scope')[0])
    scope = fields(source.split('class Scope extends RefCounted:\n')[1].split('\n\nstatic func ')[0])
    require([name for name, _ in owners] == EXPECTED_OWNERS, 'complete original owner tuple')
    require([name for name, _ in scope] == EXPECTED_SCOPE, 'complete private Scope tuple')
    for name, _ in owners:
        require(source.count('target.' + name + ' = source.' + name + '\n') == 1, 'exact owner copy: ' + name)
        require(source.count('first.' + name + ' == second.' + name) == 1, 'exact owner comparison: ' + name)
    require(source.count('Owners.new()') == 1 and source.count('.new()') == 1, 'one Scope-owned packet allocation')
    require('scope._owners = original' not in source, 'no mutable caller packet alias')
    require('var code: StringName = cleared_refusal(scope, original_host, original_session)' in source,
            'all leaves precede first owner release')
    release = source.split('static func release_preflighted(')[1].split('\n\nstatic func ')[0]
    require(re.findall(r'(Buildings|Construction|Work|Inventory)\.world_retirement_release_preflighted_in', release)
            == ['Buildings', 'Construction', 'Work', 'Inventory'], 'four owner releases in fixed order')
    require(not re.search(r'\bo\.\w+\._\w+\s*=(?!=)', source), 'kernel never writes foreign owner fields')
    frame_map = {}
    for name, text in sources.items():
        if name != 'Session':
            frame_map.update(functions(text, name, name != 'Retirement'))
    for frame in frame_map.values():
        frame['calls'] = [name for name in frame['calls'] if name in frame_map]
    numeric, chain = longest(frame_map, 'numeric_and_name_bytes')
    references, reference_chain = longest(frame_map, 'reference_values')
    session = fields(sources['Session'].split('\n\nfunc ')[0])
    session_numeric = sum(WIDTH.get(kind, 0) for _, kind in session)
    session_refs = sum(kind not in WIDTH for _, kind in session)
    require((session_numeric, session_refs) == (27, 24), 'existing Session member census changed')
    for name, value in [('CONTROL_BYTES', 1024), ('HELPER_BYTES', 512)]:
        require(re.search(rf'^const {name}: int = {value}$', sources['Session'], re.M), 'Session allowance unchanged')
    own_numeric = 2 * sum(WIDTH.get(kind, 0) for _, kind in owners) + sum(WIDTH.get(kind, 0) for _, kind in scope)
    own_refs = 2 * sum(kind not in WIDTH for _, kind in owners) + sum(kind not in WIDTH for _, kind in scope)
    require(re.findall(r'^const (\w+): (\w+)', source, re.M) ==
            [('RETIREMENT_RESERVED_BYTES', 'int'), ('NULL_REF', 'Vector2i')], 'exact numeric constants')
    require('const RETIREMENT_RESERVED_BYTES: int = 8192\n' in source, 'authorized finite retirement slice')
    constants = 16
    # An explicit proposal, not an observed allocator cost or a production numeric constant.
    provisional_control = own_numeric + constants + own_refs * 32 + 3 * 256 + 2048
    provisional_helper = numeric + references * 32 + 256
    require(provisional_control <= 6144 and provisional_helper <= 2048, 'proposal requires a larger reviewed slice')
    inventory = sources['Inventory']
    require('if _spatial_container_slot.is_empty():\n\t\t_allocate_spatial_arena(capacity)' in inventory,
            'only initial bind may allocate the endpoint arena')
    require('or not _spatial_arena_accepts(capacity):' in inventory, 'exact old arena admission')
    return {
        'source_sha256': {FILES[name]: hashlib.sha256(text.encode()).hexdigest() for name, text in sources.items()},
        'scope': 'Source-derived logical/reference census and provisional native allowances only',
        'module_retained_fields': 0, 'packed_bank_delta': 0,
        'original_session': {'numeric_bytes': session_numeric, 'reference_slots': session_refs,
                             'already_reserved_bytes': 1536},
        'additional_simultaneous_caller_and_scope': {'numeric_bytes': own_numeric, 'reference_slots': own_refs,
            'objects': ['caller Owners (prefer host permanent operational packet)', 'private Scope', 'Scope-owned fixed Owners copy'],
            'owners_fields': owners, 'scope_fields': scope},
        'joint_member_numeric_bytes': session_numeric + own_numeric,
        'joint_member_reference_slots': session_refs + own_refs,
        'additional_numeric_constant_bytes': constants,
        'static_frames': frame_map, 'maximum_numeric_chain_bytes': numeric, 'maximum_numeric_chain': chain,
        'maximum_reference_chain_values': references, 'maximum_reference_chain': reference_chain,
        'proposal': {'additional_retirement_only_bytes': 8192, 'control_slice': 6144, 'helper_slice': 2048,
            'control_arithmetic': {'numeric': own_numeric, 'constants': constants, 'reference_allowance': own_refs * 32,
                'three_control_object_allowance': 768, 'shared_script_symbols_and_native_allowance': 2048,
                'total_provisional': provisional_control, 'remaining': 6144 - provisional_control},
            'helper_arithmetic': {'numeric': numeric, 'reference_allowance': references * 32,
                'caller_and_expression_allowance': 256, 'total_provisional': provisional_helper,
                'remaining': 2048 - provisional_helper},
            'reference_slot_assumption_bytes': 32, 'object_header_assumption_bytes': 256,
            'assumptions_are_measured': False, 'adopted': False, 'logical_carve_out_authorized': True,
            'current_1156_joint_bytes_parent_reported': 238676,
            'proposed_profile_joint_bytes': 238676 + 8192, 'unchanged_profile_ceiling': 262144,
            'proposed_joint_remaining': 262144 - 238676 - 8192},
        'lifetime': 'One original Session, one caller Owners and one private Scope/copy coexist. Existing Session1536 is charged once; '
                    '8192 is an additional retirement-only proposal inside the unchanged Profile envelope. No images are copied. '
                    'The host must drop its Scope on success or abandonment before resuming admission; a Session retaining its own Scope '
                    'must explicitly break that temporary strong cycle. No per-resident clock or owner bank is created.',
        'native_measured': False, 'runtime_qualified': False,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    data = json.dumps(build(args.root), indent=2) + '\n'
    if args.out:
        if args.out.is_symlink() or args.out.exists():
            raise ValueError('create-only census output')
        args.out.write_text(data)
    else:
        print(data, end='')
