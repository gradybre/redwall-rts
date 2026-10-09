#!/usr/bin/env python3
"""1184 initial lifecycle only: exact source closure and unchanged logical envelopes.

The baseline is captured current bytes, not a hook that executes historical builds.
All input/producer bytes are checked before importing only three reviewed parsers.
References (32 B), headers (256 B) and native terms remain provisional.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
BASELINE_SHA = '74ccae51f1fdfc45b3d9e6bedce915dd1672260e1015aa424b01ae51e67fe00a'
CONTROL_CEILING = 6208
HELPER_CEILING = 1984
RESERVED_BYTES = 8192
FILES = {
    'Host': 'godot/scripts/systems/settlement_system.gd',
    'Session': 'godot/scripts/core/underground_session.gd',
    'Retirement': 'godot/scripts/core/underground_world_retirement.gd',
    'Composition': 'godot/scripts/core/underground_room_composition.gd',
    'RouteComposition': 'godot/scripts/core/underground_route_composition.gd',
    'SurfaceAnchor': 'godot/scripts/core/underground_surface_anchor.gd',
}
PRODUCERS = {
    'base': 'docs/validation/evidence/underground-route-owner-composition-2026-10-04/census.py',
    'ctor': 'docs/validation/evidence/underground-room-owner-composition-2026-10-04/constructor_census.py',
    'guard': 'docs/validation/evidence/underground-surface-anchor-lifecycle-2026-10-05/census.py',
}
ALIASES = {
    'Catalog': 'underground_connector_catalog', 'WorldRoutes': 'underground_world_routes',
    'Routes': 'underground_routes', 'Movement': 'movement', 'Residents': 'residents',
    'Owner': 'underground_space_owner', 'Domain': 'room_space', 'Value': 'room_space',
    'IntResult': 'int_math', 'Levels': 'underground_level_catalog', 'Locations': 'underground_locations',
    'RoomBindings': 'underground_room_bindings', 'RoomCatalog': 'room_catalog',
    'Provider': 'underground_world_bindings', 'Authority': 'underground_space_authority',
    'Sites': 'excavation_sites', 'Funding': 'excavation_inventory', 'Router': 'modular_projects',
    'Orders': 'underground_room_orders', 'Profiles': 'underground_profiles', 'Inventory': 'inventory', 'Construction': 'construction',
    'Work': 'work', 'Reservations': 'reservations', 'Directory': 'entity_directory',
    'Planner': 'haul_planner', 'Policy': 'store_policy', 'Buildings': 'buildings',
    'GroundPiles': 'ground_piles', 'EntryBindings': 'underground_entry_bindings',
    'Connectors': 'room_connectors',
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def inputs(replacements=None, captured=None):
    """Injected current bytes never fall back to metadata or bypass captured immutable predecessors."""
    data = (captured or {}).get('baseline/manifest.json', (HERE / 'baseline/manifest.json').read_bytes())
    require(sha(data) == BASELINE_SHA, 'immutable baseline manifest drift')
    rows = json.loads(data)
    old = {}
    for name, row in rows.items():
        payload = (captured or {}).get(row['locator'], (ROOT / row['locator']).read_bytes())
        require(sha(payload) == row['sha256'], 'immutable input/producer drift: ' + name)
        old[name] = payload.decode()
    require(not replacements or set(replacements) <= set(rows), 'unknown current source replacement')
    current = {}
    for name, text in old.items():
        if not name.endswith('.gd'):
            continue
        current[name] = (replacements or {}).get(name, (ROOT / name).read_text())
        if name not in FILES.values():
            require(current[name] == text, 'unchanged concrete constructor/source: ' + name)
    # No module executes until the complete fixed closure has matched.
    modules = {}
    for key, name in PRODUCERS.items():
        spec = importlib.util.spec_from_file_location('ug1184_' + key, ROOT / name)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        modules[key] = module
    return old, current, modules


def allocation_calls(row):
    code = re.sub(r'""".*?"""|#[^\n]*', '', row['body'], flags=re.S)
    return sorted(re.findall(r'\b[\w.]+\.(?:new|resize|duplicate|append|append_array)\([^\n]*', code))


def call_names(row):
    code = re.sub(r'""".*?"""|#[^\n]*', '', row['body'], flags=re.S)
    code = re.sub(r'&?"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', code)
    return set(re.findall(r'\b([\w.]+)\(', code))


def source_guards(old, own, base, guard):
    """Complete member initializers and allocations, plus the exact shortened construction lifetime."""
    for name, text in own.items():
        actual = guard.declaration_blocks(text)
        expected = guard.declaration_blocks(old[FILES[name]])
        if name == 'Host':
            for extra in (
                'const HaulPlannerScript := preload("res://scripts/core/haul_planner.gd")',
                'const StorePolicyScript := preload("res://scripts/core/store_policy.gd")',
                'var _haul_planner: HaulPlannerScript = null',
                'var _store_policy: StorePolicyScript = null',
            ):
                require(actual.count(extra) == 1, 'exact original Host addition: ' + extra)
                actual.remove(extra)
        if name == 'Composition':
            actual = [s.replace('core/underground_entry_bindings.gd', 'core/underground_room_bindings.gd') for s in actual]
            require(text.count('preload("res://scripts/core/underground_entry_bindings.gd")') == 1,
                    'initial exact EntryBindings subtype')
        require(actual == expected, 'uncharged member/constant initializer: ' + name)
        previous = base.parse(old[FILES[name]], name)
        parsed = base.parse(text, name)
        for key, row in parsed.items():
            before = previous.get(key, {'values': [], 'body': ''})
            require(guard.allocation_signature(row) == guard.allocation_signature(before),
                    'uncharged collection allocation: ' + key)
            expected_calls = allocation_calls(before)
            if key == 'Host._compose_haul_planning':
                expected_calls = ['HaulPlannerScript.new()', 'StorePolicyScript.new(_buildings, _inventory)']
            if key == 'RouteComposition.construct':
                expected_calls = ['WorldRoutes.new()']
            require(allocation_calls(row) == expected_calls, 'unreconciled allocation phase: ' + key)
            calls = call_names(before)
            added = {
                'Host._init': {'_compose_haul_planning'},
                'Host._clear_stores': {'_haul_planner.clear', '_store_policy.clear'},
                'Host.prepare_world_reset': {'_haul_owners_refusal'},
                'Host._mounted_underground_refusal': {'_haul_owners_refusal'},
                'Host._compose_haul_planning': {'StorePolicyScript.new', 'HaulPlannerScript.new',
                    '_haul_planner.bind', '_haul_owners_refusal', 'push_error'},
                'Host._haul_owners_refusal': {'_haul_planner.get_script', '_store_policy.get_script'},
                'Retirement._constructor_shape_refusal': {'o.room_bindings.get_script'},
            }
            calls |= added.get(key, set())
            if key == 'RouteComposition.construct':
                calls |= call_names(previous['RouteComposition._prepare_candidate'])
                calls.remove('_prepare_candidate')
            require(call_names(row) == calls, 'unreconciled transitive call: ' + key)
    for klass in ('Owners', 'Scope'):
        require(guard.nested_declarations(own['Retirement'], klass) ==
                guard.nested_declarations(old[FILES['Retirement']], klass), 'unchanged original ' + klass)
    frames = base.parse(own['RouteComposition'], 'RouteComposition')
    require('RouteComposition._prepare_candidate' not in frames, 'old extra constructor frame returned')
    construct = frames['RouteComposition.construct']['body']
    order = ['_configuration(session._retirement_owners)', '_prepare_catalog(config)',
             'candidate.configure(config)', 'session._retirement_owners.world_routes = candidate',
             'session._operations_prefix = 5', 'config = null', '_bind_graph(session)']
    positions = [construct.index(value) for value in order]
    require(positions == sorted(positions) and construct.count('config = null') == 1,
            'temporary Configuration released before graph allocation')
    require(frames['RouteComposition._prepare_catalog']['values'] ==
            [('config', 'WorldRoutes.Configuration'), ('code', 'StringName')], 'no duplicate Owners argument')
    require(own['Session'] == old[FILES['Session']] and own['SurfaceAnchor'] == old[FILES['SurfaceAnchor']],
            'unchanged Session and retained Surface lifecycle')
    host = base.parse(own['Host'], 'Host')
    require(host['Host._init']['body'].count('_compose_haul_planning()') == 1,
            'one Host construction call')
    require(host['Host._clear_stores']['body'].count('_haul_planner.clear()') == 1 and
            host['Host._clear_stores']['body'].count('_store_policy.clear()') == 1,
            'original planning arenas clear exactly once')
    leaf = host['Host._haul_owners_refusal']['body']
    require(set(re.findall(r'\b([\w.]+)\(', re.sub(r'""".*?"""', '', leaf, flags=re.S))) ==
            {'_haul_planner.get_script', '_store_policy.get_script'}, 'no owner-observing new leaf')
    require('const RETIREMENT_RESERVED_BYTES: int = 8192' in own['Retirement'], 'unchanged original reserve')


def frame_getter(own, current, ctor):
    def get(label):
        module, method = label.split('.', 1)
        nested = None
        if module in ('Domain', 'Value', 'IntResult'):
            nested = module
        if module in ('EdgeBank', 'MotionBank', 'EndpointRetention'):
            nested, module = module, 'Routes'
        if module == 'Certificates':
            nested, module = module, 'WorldRoutes'
        if module in ('LocationBank', 'InventoryLocations'):
            nested, module = ('Bank' if module == 'LocationBank' else module), 'Locations'
        if module.endswith('Result') and module != 'IntResult':
            nested, module = 'OpResult', module[:-6]
        text = own[module] if module in own else current['godot/scripts/core/' + ALIASES[module] + '.gd']
        return ctor.frame(text, method, nested)
    return get


def constructor(previous, get):
    """Rebuild each accepted finite case from current complete frames; preserve exact foreign heap charges."""
    result = {}
    for name, prior in previous['cases'].items():
        labels = [key for key in prior['chain'] if key != 'RouteComposition._prepare_candidate']
        rows = {key: get(key) for key in labels}
        declared = sum(row['provisional_frame_bytes'] for row in rows.values())
        result[name] = dict(prior, chain=labels, frames=rows, declared_provisional_bytes=declared,
                            total=declared + prior['transient_heap_bytes'] + prior['expression_bytes'])
    maximum = max(result, key=lambda key: result[key]['total'])
    return {'cases': result, 'maximum_case': maximum, 'maximum_provisional_bytes': result[maximum]['total'],
            'scope': 'Same complete foreign heap/arena lifetimes; all current source bytes pinned before use.'}


def reset_phases(prior, own, current, base):
    frames = {}
    for phase in prior['phases'].values():
        frames.update(phase['frames'])
    for name, text in own.items():
        frames.update(base.parse(text, name))
    for name in ('Planner', 'Policy'):
        frames.update(base.parse(current['godot/scripts/core/' + ALIASES[name] + '.gd'], name))
    for row in frames.values():
        if 'body' in row:
            row['calls'] += ['SurfaceAnchor.' + method for method in
                             re.findall(r'\bSurfaceAnchor\.([a-z_]\w*)\(', row['body'])]
            row['calls'] = sorted(set(row['calls']))
    frames['Host._clear_stores']['calls'] += ['Planner.clear', 'Policy.clear']
    result = {name: base.peak(frames, roots) for name, roots in {
        'reset_with_ui': ['UI.create_world'],
        'direct_reset_failure_abandon': ['Host.reset', 'Host.prepare_world_reset',
                                        'Host.abandon_world_reset', 'Host._notification'],
        'room_constructor_result': ['Host.compose_underground_room_owners'],
        'route_constructor_result': ['Host.compose_underground_route_owners'],
        'surface_constructor_result': ['Host.compose_underground_surface_anchor'],
    }.items()}
    for phase in result.values():
        for row in phase['frames'].values():
            row.pop('body', None)
            row.pop('values', None)
    return result


def class_fields(text, klass):
    match = re.search(r'^class ' + klass + r'(?: extends [^:]+)?:\n(.*?)(?=^\S|\Z)', text, re.M | re.S)
    require(match is not None, 'missing fixed packet ' + klass)
    return dict(re.findall(r'^\tvar (\w+): ([\w.]+)', match[1], re.M))


def existing_owners(current, base, get):
    """Existing real finite stores are charged once; constructor temporaries and native objects remain explicit."""
    entry = current['godot/scripts/core/underground_entry_bindings.gd']
    fields = base.members(entry)
    record = class_fields(current['godot/scripts/core/underground_locations.gd'], 'Record')
    placement = class_fields(current['godot/scripts/core/room_connectors.gd'], 'Placement')
    entry_numeric = sum(base.WIDTH.get(t, 0) for t in fields.values())
    entry_packets = 2 * sum(base.WIDTH.get(t, 0) for t in record.values()) + sum(base.WIDTH.get(t, 0) for t in placement.values())
    require('const ENTRY_FIXED_BYTES: int = 4096' in entry and entry_numeric + entry_packets < 4096,
            'existing EntryBindings logical reserve')
    require(set(re.findall(r'^var (\w+):[^\n]*\.new\(\)', entry, re.M)) ==
            {'_entry_anchor', '_entry_contact', '_entry_transform'}, 'three existing Entry packets only')
    cases = {}
    for key, tail in {
        'policy_init': ['Policy._init', 'Policy.clear'],
        'policy_directory': ['Policy._init', 'Buildings.directory'],
        'planner_init': ['Planner._init', 'Planner.clear'],
        'planner_bind': ['Planner.bind'],
        'planner_result_initializer': ['IntResult._init'],
        'final_owner_leaf': ['Host._haul_owners_refusal'],
    }.items():
        labels = ['Host._init', 'Host._compose_haul_planning'] + tail
        rows = {label: get(label) for label in labels}
        cases[key] = {'chain': labels, 'frames': rows,
                      'provisional_bytes': sum(row['provisional_frame_bytes'] for row in rows.values()) + 256}
    # The three original fixed result objects are allocated as member initializers,
    # before Planner._init. Include their simultaneous numeric slots + headers in
    # this disjoint cold phase; their retained counters are already source-enumerated
    # in the existing Planner owner. No Session or retirement Scope exists yet.
    planner = current['godot/scripts/core/haul_planner.gd']
    fixed = {'number': class_fields(current['godot/scripts/core/int_math.gd'], 'IntResult'),
             'place': class_fields(current['godot/scripts/core/ground_piles.gd'], 'PlaceResult'),
             'destination': class_fields(planner, 'Destination')}
    numeric = sum(base.WIDTH.get(t, 0) for fields in fixed.values() for t in fields.values())
    initialization = max(row['provisional_bytes'] for row in cases.values()) + numeric + 3 * 256
    return {'planner_record_bytes': 196608, 'planner_scratch_bytes': 34916,
            'policy_packed_bytes': 2363392, 'additional_global_packed_bytes': 0,
            'new_host_reference_values': 2, 'initialization_cases': cases,
            'planner_original_packet_numeric_bytes': numeric,
            'planner_original_packet_provisional_headers': 3 * 256,
            'initialization_provisional_peak': initialization,
            'entry_initial_numeric_bytes': entry_numeric,
            'entry_existing_packet_numeric_bytes': entry_packets,
            'entry_existing_reservation': 4096, 'entry_constructor_packets': 3,
            'entry_constructor_packed_payload_bytes': 0,
            'native_inventory': {'planner_object': 1, 'planner_packed_buffers': 11,
                                 'planner_packet_objects': 3, 'policy_object': 1,
                                 'policy_packed_buffers': 3, 'entry_extra_packets': 3,
                                 'entry_empty_packed_headers': 6},
            'native_measured': False,
            'scope': 'Original finite Planner/Policy/Entry reservations already exist in the global pack. '
                     'This initial slice allocates no Entry row/bearing payload or authority. '
                     'Native object, packed-header and fixed-packet storage is explicitly unmeasured; '
                     'source enumeration is not a process-allocation certificate.'}


def build(replacements=None, captured=None):
    old, current, modules = inputs(replacements, captured)
    base, ctor, guard = modules['base'], modules['ctor'], modules['guard']
    own = {name: current[path] for name, path in FILES.items()}
    source_guards(old, own, base, guard)
    pack = json.loads(old['docs/planning/underground_memory_pack.json'])
    previous = pack['room_extension_reservation']['route_composition']
    require(previous['accounting']['controls'] == 6131 and previous['accounting']['helpers'] == 1919,
            'exact accepted current predecessor arithmetic')
    get = frame_getter(own, current, ctor)
    route = constructor(previous['route_constructor'], get)
    room = constructor(pack['room_extension_reservation']['composition']['constructor'], get)
    phases = reset_phases(previous, own, current, base)
    owners = existing_owners(current, base, get)
    controls = previous['accounting']['controls'] + owners['new_host_reference_values'] * 32
    helper = max(row['provisional_bytes'] for row in phases.values())
    require(CONTROL_CEILING == 6208 and HELPER_CEILING == 1984 and RESERVED_BYTES == 8192,
            'exact reviewed internal repartition, no enlarged envelope')
    require(controls <= CONTROL_CEILING and helper <= HELPER_CEILING, 'controls/helpers exceed internal partition')
    remaining = controls - previous['constructor_exclusive_reuse']['absent_original_scope_and_copy_bytes']
    peak = max(route['maximum_provisional_bytes'], room['maximum_provisional_bytes'],
               previous['surface_constructor']['provisional_total'])
    require(remaining + peak <= RESERVED_BYTES, 'constructor coexistence exceeds original reserve')
    require(owners['initialization_provisional_peak'] <= HELPER_CEILING, 'new Host constructor helper exceeds partition')
    return {'scope': '1184 initial Host Planner/Policy + initial EntryBindings lifecycle only; no full Entry composition.',
            'baseline_manifest_sha256': BASELINE_SHA,
            'current_source_sha256': {name: sha(text.encode()) for name, text in current.items()},
            'accounting': {'previous_control_ceiling': 6144, 'previous_helper_ceiling': 2048,
                           'controls': controls, 'control_ceiling': CONTROL_CEILING,
                           'helpers': helper, 'helper_ceiling': HELPER_CEILING,
                           'retirement_reserved_bytes': RESERVED_BYTES,
                           'existing_session_reserved_bytes': 1536,
                           'profile_joint_bytes': previous['accounting']['profile_joint'],
                           'additional_global_reserved_bytes': 0},
            'phases': phases, 'route_constructor': route, 'room_constructor': room,
            'unchanged_surface_constructor': previous['surface_constructor'],
            'constructor_exclusive_reuse': {'absent_scope_and_private_copy_bytes': 2097,
                'remaining_controls': remaining, 'constructor_stack_and_heap': peak,
                'simultaneous_total': remaining + peak, 'ceiling': RESERVED_BYTES,
                'remaining': RESERVED_BYTES - remaining - peak},
            'existing_owners': owners, 'native_measured': False, 'runtime_qualified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    args.out.write_text(json.dumps(build(), indent=2) + '\n')
