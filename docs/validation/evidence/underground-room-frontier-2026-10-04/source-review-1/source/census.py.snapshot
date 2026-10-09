#!/usr/bin/env python3
"""1157 source-counted synchronous cold packets, never a global or per-Room reserve."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import textwrap

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools'))
import underground_memory_budget as memory

SOURCE = 'godot/scripts/core/underground_room_frontier.gd'
WIDTH = {'int': 8, 'bool': 1, 'Vector2i': 8, 'Vector3i': 12}


def functions(text):
    lines = text.splitlines()
    result = {}
    for index, line in enumerate(lines):
        match = re.match(r'^static func (\w+)\(', line)
        if not match:
            continue
        end = index + 1
        while end < len(lines) and (not lines[end].strip() or lines[end].startswith((' ', '\t'))):
            end += 1
        body = '\n'.join(lines[index:end]).rstrip()
        assert len(body.splitlines()) <= 30, (match[1], len(body.splitlines()))
        body = re.sub(r'#.*', '', re.sub(r'""".*?"""', '', body, flags=re.S))
        size = sum(WIDTH[t] for t in re.findall(r'\b\w+\s*:\s*(int|bool|Vector2i|Vector3i)\b', body))
        result[match[1]] = (size, body)
    return result


def chain(found, entry):
    def walk(name, stack):
        size, body = found[name]
        children = set(re.findall(r'(?<![\w.])(\w+)\(', body)) & found.keys() - stack - {name}
        below = [walk(child, stack | {name}) for child in children]
        maximum = max(below, key=lambda item: (item[0], item[1])) if below else (0, [])
        return size + maximum[0], [name] + maximum[1]
    size, names = walk(entry, set())
    return {'bytes': size, 'frames': {name: found[name][0] for name in names}}


def build(checkpoint):
    text = (ROOT / SOURCE).read_text()
    assert memory.explicit_members(text) == {}, 'module must remain stateless'
    candidate = memory.explicit_members(textwrap.dedent(memory.class_body(text, 'Candidate', 'RefCounted')))
    query = memory.explicit_members(textwrap.dedent(memory.class_body(text, 'Query', 'RefCounted')))
    candidate_bytes = sum(WIDTH.get(t, 0) for t in candidate.values())
    query_numeric = sum(WIDTH.get(t, 0) for t in query.values())
    assert candidate_bytes == 99 and query_numeric == 92
    assert {n:t for n,t in query.items() if t not in WIDTH and not t.startswith('Packed')} == {
        'provider':'Provider', 'config':'WorldRoutes.Configuration', 'actual_routes':'WorldRoutes',
        'face':'Face', 'sites':'Sites', 'budget':'Budget', 'original':'Candidate',
        'candidate':'Candidate', 'request':'Face.Request'}
    assert [n for n, t in query.items() if t.startswith('Packed')] == ['remaining_out']
    assert text.count('Candidate.new()') == 1 and text.count('Face.Request.new()') == 1
    assert text.count('Query.new()') == 1 and text.count('.new()') == 3
    assert re.findall(r'\b(\w+)\.resize\((\d+)\)', text) == [('remaining_out', '1')]
    assert len(re.findall(r'Packed\w+Array\(', text)) == 1
    assert not re.search(r'\.(append|append_array|duplicate)\(', text)
    found = functions(text)
    admission = found['contact_into'][1]
    assert admission.index('_guard(') < admission.index('_candidate_leaf(') < admission.index('Query.new()')
    assert 'const CONTROL_BYTES: int = 2048' in text and 'const COLD_BYTES: int = Face.COLD_BYTES + CONTROL_BYTES' in text
    assert 'query.remaining = checks - _scope_checks(actual)' in text
    assert 'query.remaining = query.remaining_out[0]' in text
    helpers = {name: chain(found, name) for name in found}
    maximum = max(helpers.values(), key=lambda item: item['bytes'])
    assert maximum['bytes'] <= 512
    phase_path = ROOT / 'docs/validation/evidence/underground-room-phases-2026-10-04/census.py'
    spec = importlib.util.spec_from_file_location('accepted_phase_census', phase_path)
    phase = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(phase)
    phase.DIAGNOSTIC = checkpoint.resolve()
    foreign = {
        'provider_binding': phase.own_chain(phase.P, '_ordinary_binding_leaf'),
        'provider_qualification': phase.own_chain(phase.P, 'qualification_revision'),
        'complete_static_path_local': phase.own_chain(phase.W, 'profile_reachability_refusal'),
        'work_face': phase.own_chain(phase.F, 'solid_face_refusal'),
        'finish_face': phase.own_chain(phase.F, 'finish_face_refusal'),
        'full_generation_leaf': phase.own_chain(phase.F, '_typed_row', 'FinishCheck'),
        'location_row': phase.own_chain(phase.L, '_get32'),
        'owner_source_search': phase.own_chain('underground_space_owner', '_find_source'),
    }
    assert all(row['bytes'] <= 512 for row in foreign.values())
    # The512 foreign slice is conservative: the already reviewed static route
    # certificate/search chain has its own512 helper ceiling; WorkFace's whole
    # Check/FinishCheck and foreign helper lifetimes are included in Face.COLD_BYTES.
    complete_helper_bound = maximum['bytes'] + 512 + 128
    assert complete_helper_bound <= 1024
    caller = candidate_bytes + 68
    query_fixed = query_numeric + candidate_bytes + 68 + 4
    accounted = caller + query_fixed + 1024 + 512
    assert (caller, query_fixed, accounted) == (167, 263, 1966) and accounted <= 2048
    phase_record = phase.build()
    face_bytes = phase_record['sequential_cold_peaks']['work_face_before_plans']
    cold = face_bytes + 2048
    assert face_bytes == 378880 and cold == 380928 and cold < 1048960
    return {
        'scope': __doc__, 'source_sha256': hashlib.sha256(text.encode()).hexdigest(),
        'module_retained_fields': {}, 'global_new_reservation': 0,
        'caller_candidate_fields': candidate, 'caller_candidate_bytes': candidate_bytes,
        'caller_request_bytes': 68, 'caller_total': caller,
        'private_query_fields': query, 'private_query_numeric': query_numeric,
        'private_query_plus_copied_candidate_request_and_i32': query_fixed,
        'all_declared_frames': {n: row[0] for n, row in found.items()},
        'maximum_own_chain': maximum, 'foreign_local_chains': foreign,
        'foreign_helper_bound': 512, 'expression_result_allowance': 128,
        'complete_numeric_helper_bound': complete_helper_bound,
        'helper_reservation': 1024, 'included_reference_native_allowance': 512,
        'cold_controls_accounted': accounted, 'cold_control_reservation': 2048,
        'cold_control_slack': 2048-accounted,
        'full_work_face_bytes': face_bytes, 'frontier_peak_cold_bytes': cold, 'existing_cold_ceiling': 1048960,
        'shared_phase_peak_without_frontier_packets': phase_record['sequential_cold_peaks']['mixed_entry_structure_check'],
        'caller_lifetime': 'Create Candidate and Request only after cold admission; both and the private query must die before release and before phase admission. They are not retained contact or progress receipts.',
        'work_limits': 'One canonical scan, one declared-contact scan, at most one complete WorkFace/FinishCheck, two actual static directed path queries. New scan/path counter is monotonically consumed; WorkFace retains its original independently bounded cold checks, never multiplied in a candidate loop.',
        'native_measured': False, 'runtime_qualified': False,
        'diagnostic_dependency': str(checkpoint.resolve()),
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--dependency-checkpoint', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(build(args.dependency_checkpoint), indent=2))
