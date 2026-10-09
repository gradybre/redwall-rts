#!/usr/bin/env python3
"""Source-count the 1124 scalar delta and bounded numeric paths, not native RAM."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[4]
CORE = ROOT / 'godot/scripts/core'
WIDTH = {'int': 8, 'bool': 1, 'Vector2i': 8, 'Vector3i': 12}
BASE = 'f6d3bdb33edcb550adb08bc15b2034e9f77c54e5'
PREFIX = ['underground_world_routes:profile_reachability_refusal', 'underground_world_routes:_reach_search']
SEARCH = PREFIX + ['underground_world_routes:_reach_path', 'underground_routes:_find_path']
RELAX = SEARCH + ['underground_routes:_relax_edges']
SOURCE = PREFIX + ['underground_world_routes:_reach_sources_refusal', 'underground_world_routes:_reach_endpoint_refusal',
                   'underground_world_routes:_reach_section_refusal', 'underground_locations:_resolve_section_refusal']
PATHS = {
    'witness_chain': PREFIX + ['underground_world_routes:_reach_path', 'underground_world_routes:_witness_chain_matches'],
    'witness_keys': PREFIX + ['underground_world_routes:_reach_path', 'underground_world_routes:_witness_key_matches'],
    'fresh_search_heap': RELAX + ['underground_routes:_relax', 'underground_routes:_heap_insert',
                                 'underground_routes:_heap_up', 'underground_routes:_heap_swap'],
    'fresh_search_mask': RELAX + ['underground_routes:_path_profile_refusal', 'underground_routes:_committed_mask_refusal',
                                 'underground_routes:_spend'],
    'fresh_search_index': RELAX + ['underground_routes:_first_edge_index', 'underground_routes:_edge_pair'],
    'fresh_search_take': SEARCH + ['underground_routes:_heap_take', 'underground_routes:_heap_swap'],
    'fresh_path_collect': SEARCH + ['underground_routes:_collect_path', 'underground_routes:_edge_pair'],
    'final_chain': PREFIX + ['underground_routes:_path_chain_refusal', 'underground_routes:_committed_mask_refusal',
                             'underground_routes:_spend'],
    'source_row': SOURCE + ['underground_locations:_resolve_source_row'],
    'source_room': SOURCE + ['underground_locations:_resolve_room_source_refusal', 'entity_directory:get_typed_row',
                              'entity_directory:is_valid', 'entity_directory:is_valid_of_kind'],
    'scope_domain': PREFIX + ['underground_world_routes:_reach_stores_refusal', 'underground_final_facts:_stores_refusal',
                              'underground_final_facts:_same_domain'],
    'descriptor': PREFIX + ['underground_world_routes:_reach_descriptor'],
    'new_content_digest': PREFIX + ['underground_world_routes:_reach_stores_refusal',
                                    'underground_world_routes:_reach_content_refusal',
                                    'underground_connector_source_facts:refusal',
                                    'underground_connector_source_facts:_source_digests_match'],
}


def source(module):
    return (CORE / (module + '.gd')).read_text()


def fields(text, indent=''):
    return dict(re.findall(r'^' + re.escape(indent) + r'var (\w+): ([\w.]+)\b', text, re.M))


def numeric(members):
    return sum(WIDTH.get(kind, 0) for kind in members.values())


def packet(module, name):
    match = re.search(r'^class ' + re.escape(name) + r'(?: extends \w+(?:\.\w+)*)?:\n', source(module), re.M)
    assert match is not None, (module, name)
    rows = []
    for line in source(module)[match.end():].splitlines():
        if line.strip() and not line.startswith(('\t', ' ')):
            break
        rows.append(line)
    return numeric(fields('\n'.join(rows), '\t'))


def frame(key):
    module, name = key.split(':')
    text = source(module)
    start = re.search(r'^(?:static )?func ' + re.escape(name) + r'\(', text, re.M)
    assert start is not None, key
    end = re.search(r'^(?:static )?func ', text[start.end():], re.M)
    body = text[start.start():start.end() + end.start() if end else len(text)]
    declared = re.findall(r'(\w+)\s*:\s*([\w.]+)', body[:body.index('->')])
    declared += re.findall(r'\b(?:var|for) (\w+)\s*:\s*([\w.]+)', body)
    return {'numeric_bytes': sum(WIDTH.get(kind, 0) for _, kind in declared),
            'numeric_fields': {name: kind for name, kind in declared if kind in WIDTH},
            'borrowed_or_interned': [name for name, kind in declared if kind not in WIDTH]}


def main():
    deltas = {}
    for module in ['underground_routes', 'underground_world_routes']:
        path = 'godot/scripts/core/' + module + '.gd'
        before = fields(subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True))
        after = fields(source(module))
        assert all(after.get(name) == kind for name, kind in before.items()), 'Existing member removed/widened'
        added = {name: kind for name, kind in after.items() if name not in before}
        assert all(kind == 'int' for kind in added.values()), 'No reference, bank or per-row expansion admitted'
        deltas[module] = {'added_fields': added, 'logical_bytes': numeric(added)}
    assert deltas['underground_routes']['added_fields'] == {'_path_serial': 'int'}
    assert len(deltas['underground_world_routes']['added_fields']) == 12
    route = {
        'top_numeric': numeric(fields(source('underground_routes'))),
        'two_edge_banks': 2 * packet('underground_routes', 'EdgeBank'),
        'two_motion_banks': 2 * packet('underground_routes', 'MotionBank'),
        'domain_numeric': packet('room_space', 'Domain'),
        'region_numeric': packet('underground_space_owner', 'Region'),
        'int_result': packet('int_math', 'IntResult'),
        'pose': packet('transforms', 'Pose'),
        'two_location_numeric': 2 * packet('underground_locations', 'Record'),
        'edge_numeric': packet('underground_routes', 'Edge'),
        'actor': packet('underground_routes', 'Actor'),
        'motion_step': packet('underground_routes', 'MotionStep'),
        'four_profile_selections': 4 * packet('underground_profiles', 'Selection'),
        'two_profile_boxes': 2 * packet('underground_profiles', 'Box'),
        'fixed_packed': 216, 'cordic_constants': 120,
    }
    extras = {name: fields(source('underground_locations'))[name] for name in
              ['_last_published_token', '_room_admission', '_admission_room', '_admission_type',
               '_world_preparation', '_resolve_source_ref', '_resolve_source_hint']}
    route['later_location_controls_in_topology_reserve'] = numeric(extras)
    assert sum(route.values()) == 2110
    world = {
        'top_numeric': numeric(fields(source('underground_world_routes'))),
        'domain_numeric': packet('room_space', 'Domain'),
        'descriptor': packet('underground_profiles', 'Descriptor'),
        'two_profile_boxes': 2 * packet('underground_profiles', 'Box'),
        'location_numeric': packet('underground_locations', 'Record'),
        'region_numeric': packet('underground_space_owner', 'Region'),
        'edge_numeric': packet('underground_routes', 'Edge'),
        'int_result': packet('int_math', 'IntResult'),
        'fixed_I32_packet_and_domain_payload': 4 * (6 + 6 + 6 + 3 + 3 + 6 + 6 + 6 + 6),
    }
    assert sum(world.values()) == 958
    frames = {key: frame(key) for chain in PATHS.values() for key in chain}
    paths = {name: {'chain': chain, 'numeric_bytes': sum(frames[key]['numeric_bytes'] for key in chain)}
             for name, chain in PATHS.items()}
    peak = max(value['numeric_bytes'] for value in paths.values()) + 48
    assert peak <= 512
    result = {
        'source_sha256': {module: hashlib.sha256((CORE / (module + '.gd')).read_bytes()).hexdigest()
                          for module in sorted({key.split(':')[0] for key in frames} | set(deltas))},
        'base': BASE, 'member_delta': deltas, 'retained_delta_bytes': 104, 'new_banks': 0,
        'topology_fixed_components': route, 'topology_fixed_total': sum(route.values()), 'topology_fixed_ceiling': 2112,
        'world_routes_fixed_components': world, 'world_routes_fixed_total': sum(world.values()),
        'world_routes_control_ceiling': 4096, 'existing_helper_ceiling': 512,
        'helper_numeric_peak_including_48_expression_bytes': peak, 'paths': paths, 'frames': frames,
        'scope': 'Source-counted logical numeric/packed payload only. References, Variant headers, engine frames, '
                 'array/native allocations and hardware timing are unqualified. Existing cold images/clearance banks '
                 'are unchanged and retain their original separately admitted lifetimes.'
    }
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
