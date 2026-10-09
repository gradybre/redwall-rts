#!/usr/bin/env python3
"""1161 source-counted cold packets and sequential proof lifetimes; no native/RAM qualification."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import textwrap

ROOT = Path(__file__).resolve().parents[4]

BASE = '8373d146'
WIDTH = {'int': 8, 'bool': 1, 'Vector2i': 8, 'Vector3i': 12}
P = 'underground_room_frontier_publication'
F = 'underground_work_face'
L = 'underground_locations'
R = 'underground_routes'
W = 'underground_world_routes'
O = 'underground_space_owner'
Q = 'underground_profiles'
N = 'underground_room_frontier'
SOURCES = {}


def explicit_members(text):
    """Require unique, explicitly typed direct fields; nested locals never enter this packet inventory."""
    result = dict(re.findall(r'^var (\w+): ([\w.]+)\b', text, re.M))
    assert len(re.findall(r'^var (\w+)\b', text, re.M)) == len(result), 'untyped/duplicate member'
    return result


def source(module):
    path = 'godot/scripts/core/' + module + '.gd'
    result = (ROOT / path).read_text()
    SOURCES[path] = hashlib.sha256(result.encode()).hexdigest()
    return result


def nested(module, name):
    text = source(module)
    extends = re.findall(r'^class ' + re.escape(name) + r' extends ([^:\n]+):', text, re.M)
    assert len(extends) == 1, (module, name)
    tail = text.split('class ' + name + ' extends ' + extends[0] + ':\n')[1]
    lines = []
    for line in tail.splitlines():
        if line.strip() and not line.startswith((' ', '\t')):
            break
        lines.append(line)
    return textwrap.dedent('\n'.join(lines))


def fields(module, name):
    return explicit_members(nested(module, name))


def scalar(module, name):
    return sum(WIDTH.get(kind, 0) for kind in fields(module, name).values())


def executable(text):
    return re.sub(r'#.*', '', re.sub(r'""".*?"""', '', text, flags=re.S))


def functions(module, cls=None):
    lines = (nested(module, cls) if cls else source(module)).splitlines()
    found = {}
    for first, line in enumerate(lines):
        match = re.match(r'^(?:static )?func (\w+)\(', line)
        if not match:
            continue
        last = first + 1
        while last < len(lines) and (not lines[last].strip() or lines[last].startswith((' ', '\t'))):
            last += 1
        raw = '\n'.join(lines[first:last]).rstrip()
        if module == P or match[1].startswith(('_frontier_', 'frontier_', 'hold_frontier', 'begin_frontier_')):
            assert len(raw.splitlines()) <= 30, (module, match[1], len(raw.splitlines()))
        body = executable(raw)
        size = sum(WIDTH[kind] for kind in re.findall(r'\b\w+\s*:\s*(int|bool|Vector2i|Vector3i)\b', body))
        assert match[1] not in found
        found[match[1]] = (size, body)
    return found


def chain(module, entry, cls=None):
    found = functions(module, cls)

    def visit(name, stack):
        size, body = found[name]
        calls = re.findall(r'(?<![\w.])(?:(?:self|actual)\.)?(\w+)\s*\(', body)
        children = set(calls) & found.keys() - stack - {name}
        tails = [visit(child, stack | {name}) for child in children]
        best = max(tails, key=lambda row: (row[0], row[1])) if tails else (0, [])
        return size + best[0], [name] + best[1]

    size, names = visit(entry, set())
    prefix = module + ('.' + cls if cls else '')
    return {'bytes': size, 'frames': {prefix + '.' + name: found[name][0] for name in names}}


def joined(entries, *tails):
    frames = {module + '.' + name: functions(module)[name][0] for module, name in entries}
    for tail in tails:
        for name, value in tail['frames'].items():
            assert name not in frames, ('duplicate simultaneous frame', name)
            frames[name] = value
    return {'bytes': sum(frames.values()), 'frames': frames}


def retained_delta():
    result = {}
    for module in (L, R, W, F, 'underground_final_facts'):
        path = 'godot/scripts/core/' + module + '.gd'
        old = subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)
        before, after = explicit_members(old), explicit_members(source(module))
        new = {key: value for key, value in after.items() if key not in before}
        assert all(after.get(key) == value for key, value in before.items()), module
        assert new == ({'_frontier': 'FrontierContext'} if module == L else {}), (module, new)
        result[module] = {'added_members': new, 'numeric_packed_delta': 0,
                          'baseline_sha256': hashlib.sha256(old.encode()).hexdigest()}
    assert explicit_members(source(P)) == {}, 'publisher must remain stateless'
    return result


def build():
    text = source(P)
    found = functions(P)
    assert 'const CONTROL_BYTES: int = 8192' in text and 'const MAX_STATIONS: int = 3' in text
    assert 'const FRONTIER_HEAP_WORDS: int = 168' in source(L)
    admission = found['publish_into'][1]
    assert admission.index('Frontier._guard(') < admission.index('_input(') < admission.index('Query.new()')
    assert '_run(query, out)' in admission
    final = found['_run'][1]
    assert final.index('_final_leaf(q)') < final.index('out.get_script() != Result') < final.index('q.actual._publishing = true')
    assert 'out.locations.size() != 6 or out.edges.size() != 12' in final
    assert 'CONTROL_BYTES + maxi(config.locations.cold_peak_bytes(), maxi(Face.COLD_BYTES, WorldRoutes.COLD_BYTES)) > Budget.COLD_BYTES' in found['_input'][1]
    assert text.count('Query.new()') == 1 and text.count('_allocate(q)') == 1
    assert not re.search(r'\.(append|append_array|duplicate)\s*\(', text)
    assert re.findall(r'Packed\w+Array\(([^)]*)\)', text) == [''] * 10
    assert re.findall(r'=\s*\[([^]]*)\]', text) == ['', '']
    assert re.findall(r'\bin\s*\[([^]]*)\]', text) == [
        'Contract.OP_BRACE, Contract.OP_CUT', 'Profiles.BODY_HELD_LOAD, Profiles.TURN_RECOVERY, Profiles.WORK_APPROACH', '0, 2']
    assert not re.search(r'\b(?:range|Array|Dictionary)\s*\(', text)
    assert re.findall(r'(\w+(?:\.\w+)*)\.new\(', text) == [
        'Request', 'Frontier.Candidate', 'Locations.FrontierContext', 'Locations.Record', 'Owner.Region',
        'Profiles.Descriptor', 'Profiles.Box', 'Routes.Edge', 'Face.Request', 'Query', 'Locations.Record', 'Owner.Region']
    resize = re.findall(r'([\w.\[\]]+)\.resize\(([^)]+)\)', text)
    assert resize == [('q.request.sections', '6'), ('q.request.points', '9'), ('q.request.profiles', '12'),
        ('q.gateway.envelope', '6'), ('q.gateway.support', '6'), ('q.records', 'MAX_STATIONS'),
        ('q.sections', 'MAX_STATIONS'), ('q.records[index].envelope', '6'), ('q.records[index].support', '6'),
        ('q.sections[index].box', '6'), ('q.outer_section.box', '6'), ('q.bounds', '6'), ('q.edge.points', '6'),
        ('q.remaining_out', '1'), ('q.refs', '6'), ('q.context.refs', '6'), ('q.context.edges', '12'),
        ('q.edges', '12'), ('q.heap_patch', 'Locations.FRONTIER_HEAP_WORDS')]
    request = scalar(P, 'Request') + 4 * (6 + 9) + 8 * 12
    output = scalar(P, 'Result') + 4 * (6 + 12)
    candidate = scalar(N, 'Candidate')
    context = scalar(L, 'FrontierContext') + 4 * (6 + 12)
    record = scalar(L, 'Record') + 4 * 12
    region = scalar(O, 'Region') + 4 * 6
    edge = scalar(R, 'Edge') + 4 * 6
    query = scalar(P, 'Query') + 4 * (6 + 12 + 168 + 6 + 1)
    query_fields = fields(P, 'Query')
    assert {name: kind for name, kind in query_fields.items() if kind.startswith('Packed')} == {
        'refs': 'PackedInt32Array', 'edges': 'PackedInt32Array', 'heap_patch': 'PackedInt32Array',
        'bounds': 'PackedInt32Array', 'remaining_out': 'PackedInt32Array'}
    assert {name: kind for name, kind in query_fields.items() if kind not in WIDTH and not kind.startswith('Packed')} == {
        'provider': 'Provider', 'config': 'WorldRoutes.Configuration', 'actual': 'WorldRoutes', 'face_owner': 'Face',
        'locations': 'Locations', 'graph': 'Routes', 'input': 'Request', 'original': 'Frontier.Candidate',
        'request': 'Request', 'candidate': 'Frontier.Candidate', 'context': 'Locations.FrontierContext',
        'gateway': 'Locations.Record', 'records': 'Array', 'sections': 'Array',
        'original_location_live': 'Locations.Bank', 'original_location_stage': 'Locations.Bank',
        'original_graph_live': 'Routes.EdgeBank', 'original_graph_stage': 'Routes.EdgeBank',
        'original_masks_live': 'WorldRoutes.Certificates', 'original_masks_stage': 'WorldRoutes.Certificates',
        'outer_section': 'Owner.Region', 'descriptor': 'Profiles.Descriptor', 'box': 'Profiles.Box',
        'edge': 'Routes.Edge', 'contact': 'Face.Request'}
    packets = {'caller_request': request, 'caller_output': output, 'caller_candidate': candidate,
        'private_query_scalars_and_5_buffers': query, 'private_request': request, 'private_candidate': candidate,
        'private_context': context, 'four_Location_records': 4 * record, 'four_Region_records': 4 * region,
        'one_descriptor': scalar(Q, 'Descriptor'), 'one_box': scalar(Q, 'Box'),
        'one_reused_two_point_Edge': edge, 'one_WorkFace_Request': scalar(F, 'Request'),
        'two_simultaneous_Routes_results': 2 * scalar(R, 'Result')}
    assert (request, output, candidate, context, record, region, edge) == (204, 88, 99, 144, 116, 72, 144)
    own = {name: chain(P, name) for name in found}
    maximum = max(own.values(), key=lambda row: (row['bytes'], str(row['frames'])))
    # Foreign calls have reviewed individual cold/helper envelopes. New direct
    # cross-owner tails below include the full static call frames; the source
    # callback's own512 bound is conservative and counted once, not per call.
    tails = {
        'original_provider_binding': chain('underground_room_world_bindings', '_ordinary_binding_leaf'),
        'original_frontier_candidate': chain(N, '_candidate_leaf'),
        'actual_source_path': chain(W, 'profile_reachability_refusal'),
        'fresh_world_source_facts': chain('underground_final_facts', 'frontier_refusal'),
        'actual_current_terrain': chain('underground_terrain', '_final_local_tiles'),
        'actual_physical_occupancy': chain(W, 'workpiece_occupancy_refusal'),
        'actual_physical_selection': chain(R, 'physical_selection_into'),
        'exact_Location_rows_and_heap': chain(L, 'frontier_rows_refusal'),
        'graph_rows_and_heap': joined([(W, 'frontier_leaf_refusal'), (R, 'frontier_leaf_refusal')], chain(L, 'frontier_heap_refusal')),
        'Locations_prospective_final': chain(L, 'frontier_record_matches'),
    }
    assert all(tail['bytes'] <= 512 for tail in tails.values()), tails
    helper_bound = maximum['bytes'] + 512 + 128
    assert helper_bound <= 1024, (maximum, helper_bound)
    packed_headers = 28
    # Nineteen caller/private objects, two simultaneous result objects, two
    # reference Arrays with6 elements, their explicit borrowed/pinned fields,
    # and temporary small literals are listed, not claimed as measured sizes.
    reference_fields = sum(1 for module, cls in [(P, 'Query'), (L, 'FrontierContext')]
                           for kind in fields(module, cls).values()
                           if kind not in WIDTH and not kind.startswith(('Packed', 'Array')))
    native = {'provisional_allowance': 4096, 'caller_private_objects': 19, 'simultaneous_result_objects': 2,
        'packed_array_headers': packed_headers, 'reference_Array_headers': 2, 'reference_Array_elements': 6,
        'explicit_query_context_reference_fields': reference_fields, 'new_live_borrowed_Locations_reference': 1,
        'small_temporary_literal_max_elements': 3, 'measured': False}
    # Parameters/locals are strong aliases of the original objects, not packets.
    # The final Result alias is included in this allowance; no retained field is added.
    helper_reference_aliases = {}
    for name in maximum['frames']:
        function = name.rsplit('.', 1)[-1]
        body = found[function][1]
        kinds = re.findall(r'\b\w+\s*:\s*([\w.]+)\b', body.split('->', 1)[0])
        kinds += re.findall(r'\b(?:var|for)\s+\w+\s*:\s*([\w.]+)\b', body)
        helper_reference_aliases[name] = sum(kind not in WIDTH and kind not in ('StringName', 'void') for kind in kinds)
    native['maximum_chain_object_aliases'] = helper_reference_aliases
    native['maximum_chain_object_alias_count'] = sum(helper_reference_aliases.values())
    native['prospective_Check_borrows_existing_context'] = 1
    assert native['maximum_chain_object_alias_count'] == 15
    controls = sum(packets.values()) + 1024 + native['provisional_allowance']
    assert controls == 8050 and controls <= 8192, (packets, controls)
    budget = source('underground_budget')
    for declaration in ['const PHASE_VOLUME_CAPACITY: int = 8192', 'const REGION_CAPACITY: int = 6144',
                        'const SOURCE_CAPACITY: int = 2048',
                        'const COLD_BYTES: int = 120 * PHASE_VOLUME_CAPACITY + 32 * SOURCE_CAPACITY + 384']:
        assert declaration in budget
    assert 'return 72 * _domain._regions + 16 * _domain._regions + 384 if _domain != null else 0' in source(L)
    assert 'const COLD_BYTES: int = Routes.SNAPSHOT_BYTES + 48 * Routes.FRAGMENT_CAPACITY + CONTROL_BYTES' in source(F)
    assert 'const CONTROL_BYTES: int = 2048' in source(F)
    assert 'const SNAPSHOT_BYTES: int = 48 * Budget.REGION_CAPACITY + 16 * Budget.SOURCE_CAPACITY' in source(W)
    assert 'const FRAGMENT_CAPACITY: int = 1024' in source(W)
    assert 'const COLD_BYTES: int = SNAPSHOT_BYTES + 48 * FRAGMENT_CAPACITY + 1024' in source(W)
    sequential = {'Location_snapshot_fragments': 88 * 8192 + 384,
                  'WorkFace_complete_proof': 48 * 6144 + 16 * 2048 + 48 * 1024 + 2048,
                  'WorldRoutes_complete_proof': 48 * 6144 + 16 * 2048 + 48 * 1024 + 1024}
    assert sequential == {'Location_snapshot_fragments': 721280, 'WorkFace_complete_proof': 378880, 'WorldRoutes_complete_proof': 377856}
    retained = retained_delta()
    return {'scope': __doc__, 'baseline': BASE, 'source_sha256': SOURCES, 'packets': packets,
        'fixed_numeric_packed_total': sum(packets.values()), 'query_fields': fields(P, 'Query'),
        'context_fields': fields(L, 'FrontierContext'), 'all_publisher_declared_frames': {n: x[0] for n, x in found.items()},
        'maximum_own_chain': maximum, 'foreign_direct_chains': tails, 'foreign_bound': 512,
        'expression_return_allowance': 128, 'complete_helper_bound': helper_bound, 'helper_reservation': 1024,
        'native_and_reference_inventory': native, 'cold_controls_accounted': controls, 'cold_control_reservation': 8192,
        'sequential_proofs': sequential, 'maximum_cold_lifetime': max(sequential.values()) + 8192,
        'original_cold_ceiling': 1048960, 'shared_paid_phase_without_frontier_packets': 1048912,
        'retained_delta': retained, 'new_global_reservation': 0,
        'lifetime': 'Caller Candidate/Request/Result and private Query exist only under the admitted cold lease. All must be dropped before the separate paid phase. Existing bank/scratch owners are borrowed. WorkFace proof is destroyed before WorldRoutes compilation; Location snapshot is released by seal. The single live Locations pointer is null at quiescence and covered by its existing native/reference envelope.',
        'runtime_qualified': False, 'native_measured': False}


if __name__ == '__main__':
    print(json.dumps(build(), indent=2))
