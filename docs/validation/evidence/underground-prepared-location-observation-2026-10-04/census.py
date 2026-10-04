#!/usr/bin/env python3
"""Count decision1130 retained fields and numeric helper chains; this is not native RAM proof."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[4]
CORE = ROOT / 'godot/scripts/core'
BASE = '75096e56'
WIDTH = {'int': 8, 'bool': 1, 'Vector2i': 8, 'Vector3i': 12}
MODULES = ['underground_locations', 'underground_routes']
SOURCE_PATHS = {name: CORE / (name + '.gd') for name in MODULES}
COPY = ['underground_routes:_location_into', 'underground_locations:prepared_route_location_into',
        'underground_locations:_copy_route_observation']
BIND = ['underground_routes:_location_into', 'underground_locations:prepared_route_location_into',
        'underground_locations:_route_observation_binding_refusal', 'underground_locations:_route_observation_world_refusal']
CONTEXT = ['underground_routes:_location_into', 'underground_locations:prepared_route_location_into',
           'underground_locations:_route_observation_context_refusal', 'underground_locations:_route_observation_shape_matches']
INSTALL = ['modular_projects:complete_order', 'modular_projects:_completion_refusal', 'underground_connector_work:transition_refusal', 'underground_connector_work:_prepare_completion',
           'underground_connector_placements:prepare_completion', 'underground_connector_placements:_prepare_completion_candidates',
           'underground_connector_placements:_prepare_routes', 'underground_entry_bindings:AdmissionAuthority.stage_routes',
           'underground_entry_bindings:_stage_timber_routes', 'underground_routes:stage_refresh',
           'underground_routes:_edge_format_refusal']
SEAL = ['modular_projects:complete_order', 'modular_projects:_completion_refusal', 'underground_connector_work:transition_refusal', 'underground_connector_work:_prepare_completion',
        'underground_connector_placements:prepare_completion', 'underground_connector_placements:_prepare_completion_candidates',
        'underground_connector_placements:_prepare_routes', 'underground_world_routes:seal', 'underground_routes:seal',
        'underground_routes:_validate_graph', 'underground_routes:_edge_format_refusal']
PATHS = {'observation_copy': COPY, 'observation_binding': BIND, 'observation_context': CONTEXT,
         'actual_installation_copy': INSTALL + COPY, 'actual_installation_binding': INSTALL + BIND,
         'actual_installation_context': INSTALL + CONTEXT, 'actual_installation_seal_copy': SEAL + COPY,
         'actual_installation_seal_binding': SEAL + BIND, 'actual_installation_seal_context': SEAL + CONTEXT}


def members(text):
    declarations = [line for line in text.splitlines() if re.match(r'^var\b', line)]
    result = {}
    for line in declarations:
        match = re.match(r'^var (\w+): ([\w.]+)(?:\s|:|$)', line)
        assert match and match[1] not in result, line
        result[match[1]] = match[2]
    return result


def frame(key):
    module, name = key.split(':')
    nested = '.' in name
    name = name.split('.')[-1]
    lines = (CORE / (module + '.gd')).read_text().splitlines()
    prefix = '\t' if nested else ''
    starts = [i for i, line in enumerate(lines)
              if re.match(r'^' + prefix + r'(?:static )?func ' + re.escape(name) + r'\(', line)]
    assert len(starts) == 1, (key, starts)
    start = starts[0]
    end = start + 1
    while end < len(lines) and (not lines[end].strip() or lines[end].startswith(prefix + '\t')):
        end += 1
    body = '\n'.join(lines[start:end])
    arguments = body[:body.index('->')]
    values = re.findall(r'\b(\w+)\s*:\s*([\w.]+)', arguments)
    values += re.findall(r'\b(?:var|for) (\w+)\s*:\s*([\w.]+)', body)
    return {'numeric_bytes': sum(WIDTH.get(kind, 0) for _, kind in values),
            'numeric_fields': {name: kind for name, kind in values if kind in WIDTH},
            'borrowed_or_interned': [name for name, kind in values if kind not in WIDTH]}


def main():
    deltas = {}
    for module, path in SOURCE_PATHS.items():
        old = subprocess.check_output(['git', 'show', BASE + ':' + str(path.relative_to(ROOT))], cwd=ROOT, text=True)
        before, after = members(old), members(path.read_text())
        assert before == after, ('No retained member or width change admitted', module)
        deltas[module] = {'added_fields': {}, 'retained_numeric_delta': 0}
    names = sorted({name for path in PATHS.values() for name in path})
    frames = {name: frame(name) for name in names}
    paths = {name: {'path': path, 'numeric_bytes': sum(frames[part]['numeric_bytes'] for part in path)}
             for name, path in PATHS.items()}
    longest = max(value['numeric_bytes'] for value in paths.values())
    assert longest + 48 <= 512
    report = {
        'source_sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                          for path in SOURCE_PATHS.values()},
        'base_commit': BASE, 'retained_deltas': deltas, 'paths': paths, 'frames': frames,
        'largest_declared_numeric_chain_bytes': longest, 'expression_result_allowance_bytes': 48,
        'numeric_chain_plus_allowance': longest + 48, 'existing_nested_helper_ceiling': 512,
        'route_fixed_work_per_observation': 256, 'new_cold_images_or_arrays': 0,
        'reused_record_payload_bytes': 116,
        'record_census': 'point12 + Room/section/World24 + fourI64 controls32 + envelope/support48 =116; already reserved twice by Routes',
        'native_ram_qualification': False,
        'native_note': 'Borrowed object references, StringNames, Variant/VM frames and packed-array allocator headers are unmeasured.'}
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
