#!/usr/bin/env python3
"""1153 source-derived retained state, synchronous numeric frames and cold coexistence.

Logical accounting only. Engine Variant/reference/frame/allocator capacity is not
measured by this source census. The actual ordinary provider remains a separately
reviewed caller whose additional frames must be charged exactly once.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
BASE = 'b03fbc2b0322381248998bfc57ce0a89ee3e76c0'
sys.path.insert(0, str(ROOT / 'tools'))
import underground_memory_budget as memory

SPEC = importlib.util.spec_from_file_location('prior_census', ROOT /
    'docs/validation/evidence/underground-workpiece-spatial-2026-10-04/census.py')
prior = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(prior)
P, A, L = prior.P, prior.A, prior.L


def main():
    modules = (P, A, L)
    retained = {}
    for module in modules:
        path = f'godot/scripts/core/{module}.gd'
        original = subprocess.check_output(['git', 'show', f'{BASE}:{path}'], cwd=ROOT, text=True)
        current = (ROOT / path).read_text()
        assert memory.explicit_members(original) == memory.explicit_members(current), module
        before = re.findall(r'\b(?:\w+\.)?(?:new|resize|duplicate)\([^\n]*', original)
        after = re.findall(r'\b(?:\w+\.)?(?:new|resize|duplicate)\([^\n]*', current)
        assert before == after, f'{module}: allocation call census changed'
        retained[module] = {'top_level_members_unchanged': True,
                            'allocation_call_sites_unchanged': len(after)}
    current_locations = (ROOT / f'godot/scripts/core/{L}.gd').read_text()
    original_locations = subprocess.check_output(['git', 'show', f'{BASE}:godot/scripts/core/{L}.gd'], cwd=ROOT, text=True)
    for packet in ('PhaseContext', 'InstallationContext', 'RoomContext', 'Record', 'Bank'):
        assert memory.class_body(current_locations, packet) == memory.class_body(original_locations, packet), packet
    assert 'func prepare_room_phase_refresh(' not in (ROOT / f'godot/scripts/core/{A}.gd').read_text()
    index = memory.audit.load_source_index()
    refs = {name: 'WeakRef' for name in ('issuer', 'authority', 'sites', 'space', 'locations')}
    refs['budget'] = 'Budget'
    context = memory.scalar_packet(index, L, 'PhaseContext', refs)
    assert context == 128
    assert memory.numeric_fields(index[P].text, '') == 135
    old_fixed = json.loads((ROOT / 'docs/validation/evidence/underground-workpiece-spatial-2026-10-04/source-review-2/helper-census.json').read_text())['fixed_components']
    assert sum(old_fixed.values()) == 1895 and old_fixed['helper_frames'] == 576
    refresh = prior.own_chain(L, 'stage_refresh')
    assert refresh['bytes'] == 360
    phase = prior.chain([(A, 'operation_refusal'), (A, '_run_cold_operation'), (A, '_prepare'),
                         (P, 'prepare_room_phase_refresh'), (P, '_phase_prepare_banks'), (P, '_phase_prepare_locations')])
    phase['frames'].update(refresh['frames'])
    phase['frames']['existing_provider_prepare_companions_allowance'] = 40
    phase['bytes'] += refresh['bytes'] + 40
    assert phase['bytes'] == 564 and phase['bytes'] <= 576
    early = prior.chain([(A, 'operation_refusal'), (A, '_run_cold_operation'), (A, '_prepare'),
                         (P, 'prepare_room_phase_refresh'), (P, '_ordinary_phase_request'), (P, '_ordinary_room_refusal')])
    early['frames'][P + '.CoreSources._final_row'] = prior.functions('underground_space_owner', 'CoreSources')['_final_row'][0]
    early['frames']['existing_provider_prepare_companions_allowance'] = 40
    early['bytes'] = sum(early['frames'].values())
    assert early['bytes'] <= 576
    final = prior.chain([(A, 'final_settlement_leaf_refusal'), (A, '_final_phase_leaf'),
                         (A, 'room_phase_leaf_refusal'), (P, 'prepared_phase_leaf_refusal')])
    installed = prior.own_chain(L, '_installed_witnesses_refusal')
    final['frames'].update(installed['frames'])
    final['frames']['existing_provider_final_leaf_allowance'] = 56
    final['bytes'] += installed['bytes'] + 56
    assert final['bytes'] <= 576
    iterator = prior.own_chain(L, 'live_location_at_into')
    iterator['frames']['underground_space_owner.CoreSources._final_row'] = 24
    iterator['bytes'] += 24
    packet = memory.scalar_packet(index, L, 'Record', {'envelope': 'PackedInt32Array', 'support': 'PackedInt32Array'}) + 48
    iterator_total = iterator['bytes'] + packet + 8 + 48
    assert packet == 116 and iterator['bytes'] == 136 and iterator_total == 308 and iterator_total <= 512
    r, sources, two_plans, cold_controls = 6144, 2048, 145872, 4096
    cold = {'locations_and_two_existing_plans': 88*r + 384 + two_plans + cold_controls,
            'world_routes_and_two_existing_plans': 48*r + 16*sources + 49152 + two_plans + cold_controls}
    assert cold == {'locations_and_two_existing_plans': 691024, 'world_routes_and_two_existing_plans': 526800}
    assert max(cold.values()) <= 1048960
    paths = [f'godot/scripts/core/{name}.gd' for name in modules]
    print(json.dumps({
        'scope': __doc__.strip(), 'base': BASE,
        'source_sha256': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
        'retained_source_census': retained,
        'added_retained_numeric_bytes': 0, 'added_packed_columns_or_arrays': 0,
        'unchanged_phase_context_bytes': context,
        'unchanged_fixed_components': old_fixed,
        'placement_control_total': sum(old_fixed.values()), 'placement_control_reserve': 2048,
        'helper_reserve': 576,
        'ordinary_preparation_chain': phase, 'ordinary_initial_scope_chain': early,
        'ordinary_final_installed_chain': final,
        'provider_overlap': 'The existing 40B prepare and 56B final callback allowances are counted once here. Extra concrete 1152 provider locals/forwarding/WorkFace state must be counted in its own reviewed contribution; this component does not admit them.',
        'phase_context_lifetime': 'The same existing Placement-owned128B packet remains bound to actual Authority/Sites/Space/Locations/Budget; ordinary operation pins exact null Placement, entry pins real full Placement. No per-provider packet or new ref is retained.',
        'iterator_chain': iterator, 'caller_record_bytes': packet, 'caller_ref_bytes': 8,
        'iterator_expression_return_allowance': 48, 'iterator_total': iterator_total, 'iterator_existing_allowance': 512,
        'iterator_work': 'One source scan per live row; precharge256+4*actual_source_capacity against the original immutable Domain. No Location/Region-wide scan, source observer, image, lease, or retained hint is added. Consumer batches physical slots and performs its separate Approach proof.',
        'ordinary_work': 'The bounded absence scan costs at most the existing64*(Placement_capacity+opening_capacity) precharge per scope leaf. Complete retained payload passes still use existing_admission_row_checks; all source and Location/Route work guards remain unchanged.',
        'sequential_cold_peaks': cold, 'cold_reserve': 1048960,
        'cold_lifetime': 'Existing Authority Plans coexist with Locations proof; Locations image/fragments are released before WorldRoutes qualification. Both companions reuse preallocated banks. Concrete1152 WorkFace observation must finish and drop its survey before this phase and publish its separate combined census.',
        'runtime_qualified': False,
    }, indent=2))


if __name__ == '__main__':
    main()
