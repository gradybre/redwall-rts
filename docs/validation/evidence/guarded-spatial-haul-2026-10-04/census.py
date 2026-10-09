#!/usr/bin/env python3
"""ADR1141 source-derived fixed packets and complete lower-owner numeric lifetimes."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools'))
import underground_memory_budget as memory

BASE = '2542a860'
WIDTH = {'int': 8, 'bool': 1, 'Vector2i': 8, 'Vector3i': 12}
MODULES = ('reservations', 'inventory', 'haul_transfer_contract', 'int_math')
ALIASES = {
    'reservations': {'actual': 'reservations', 'Inventory': 'inventory', 'inventory': 'inventory', '_haul_inventory': 'inventory',
                     'HaulContract': 'haul_transfer_contract', 'IntMath': 'int_math'},
    'inventory': {'actual': 'inventory', 'HaulContract': 'haul_transfer_contract', 'IntMath': 'int_math'},
    'haul_transfer_contract': {}, 'int_math': {'IntMathScript': 'int_math'},
}


def functions(source):
    lines = source.splitlines()
    result = {}
    for start, line in enumerate(lines):
        if not re.match(r'^(?:static )?func ', line):
            continue
        end = start + 1
        while end < len(lines) and (not lines[end].strip() or lines[end].startswith(('\t', ' '))):
            end += 1
        body = '\n'.join(lines[start:end]).rstrip()
        name = re.search(r'func (\w+)', line).group(1)
        executable = re.sub(r'""".*?"""', '', body, flags=re.S)
        executable = re.sub(r'#.*', '', executable)
        numeric = re.findall(r'\b\w+\s*:\s*(int|bool|Vector2i|Vector3i)\b', executable)
        # Charge each local/parameter even when it aliases another outcome or has not yet been assigned.
        outcomes = len(re.findall(r'\b\w+\s*:\s*(?:Inventory\.)?OpResult\b', executable))
        result[name] = {'numeric': sum(WIDTH[k] for k in numeric), 'outcomes': outcomes,
                        'source': body, 'executable': executable}
    return result


def main():
    source = {m: (ROOT / 'godot/scripts/core' / (m + '.gd')).read_text() for m in MODULES}
    old = {m: subprocess.check_output(['git', 'show', f'{BASE}:godot/scripts/core/{m}.gd'],
                                     cwd=ROOT, text=True) for m in ('inventory', 'reservations')}
    assert memory.explicit_members(source['inventory']) == memory.explicit_members(old['inventory'])
    before = memory.explicit_members(old['reservations'])
    after = memory.explicit_members(source['reservations'])
    assert {k: v for k, v in after.items() if k not in before} == {
        '_haul_original': 'HaulContract.Transfer', '_haul_view': 'HaulContract.Transfer',
        '_haul_active': 'bool', '_haul_inventory': 'Inventory', '_haul_guard': 'HaulContract',
        '_haul_error': 'StringName'}
    assert all(after[k] == v for k, v in before.items())
    packet = memory.explicit_members(memory.class_body(source['haul_transfer_contract'], 'Transfer'), '\t')
    assert len(packet) == 27 and list(packet.values()).count('Vector2i') == 8 and list(packet.values()).count('int') == 19
    packet_bytes = sum(WIDTH[k] for k in packet.values())
    assert packet_bytes == 216 and 2 * packet_bytes + 1 == 433
    assert source['inventory'].count('\nclass OpResult:\n') == 1
    outcome_source = source['inventory'].split('\nclass OpResult:\n')[1].split('\n\nclass TransferPlan:')[0]
    outcomes = memory.explicit_members(outcome_source, '\t')
    assert outcomes == {'ok': 'bool', 'error': 'StringName', 'ref': 'Vector2i', 'value': 'int'}
    outcome_bytes = sum(WIDTH.get(k, 0) for k in outcomes.values())
    assert outcome_bytes == 17
    found = {f'{m}.{n}': row for m in MODULES for n, row in functions(source[m]).items()}

    def children(name):
        module = name.split('.')[0]
        result = set()
        for receiver, call in re.findall(r'(?:(\b\w+)\.)?\b(\w+)\s*\(', found[name]['executable']):
            target = ALIASES[module].get(receiver, module if not receiver else None)
            if target and f'{target}.{call}' in found and f'{target}.{call}' != name:
                result.add(f'{target}.{call}')
        return result

    def longest(name, seen=()):
        candidates = [longest(child, (*seen, name)) for child in children(name) if child not in seen]
        best = max(candidates, key=lambda item: (item[0], item[1])) if candidates else (0, [])
        row = found[name]
        return row['numeric'] + row['outcomes'] * outcome_bytes + best[0], [name] + best[1]

    entries = ['reservations.admit_haul_guarded', 'reservations.transfer_haul_guarded',
               'inventory.commit_haul_transfer_in', 'reservations._publish_haul_pool_rows']
    chains = {}
    for entry in entries:
        total, path = longest(entry)
        frames = {name: {k: found[name][k] for k in ('numeric', 'outcomes')} for name in path}
        chains[entry] = {'bytes': total, 'path': path, 'frames': frames}
    maximum = max(row['bytes'] for row in chains.values())
    assert maximum <= 512, maximum
    # The callback's concrete Delivery work is a separate reservation, borrowing the216B view.
    callback_path = ['reservations.transfer_haul_guarded', 'reservations._haul_finish_in',
                     'reservations._haul_transaction_in', 'inventory.commit_haul_transfer_in',
                     'inventory._haul_attestation_in']
    callback_base = sum(found[name]['numeric'] + found[name]['outcomes'] * outcome_bytes for name in callback_path)
    assert callback_base <= 512
    old_functions = functions(old['reservations'])
    new_functions = functions(source['reservations'])
    extracted = ['_upsert_row', '_allocate_row', '_free_row', '_pop_min', '_push_free',
                 '_compare_lot_key', '_compare_job_key', '_link_job', '_link_lot',
                 '_unlink_job', '_unlink_lot', '_find_row']
    for name in extracted:
        new_body = new_functions[name + '_in']['source'].split('\n', 1)[1]
        new_body = new_body.replace('actual.', '')
        for call in extracted:
            new_body = new_body.replace(call + '_in(actual, ', call + '(').replace(call + '_in(actual)', call + '()')
        assert new_body == old_functions[name]['source'].split('\n', 1)[1], name
    inventory_kernels = ['_close_transaction', '_clear_pile_candidates', '_reclaim_empty_piles',
                         '_reclaim_if_empty', '_retire_empty_pile', '_clear_spatial_endpoint',
                         '_free_container_slot', '_journal_scalar', '_journal_spatial_endpoint',
                         '_refuse_attestation_reentry']
    old_inventory = functions(old['inventory'])
    new_inventory = functions(source['inventory'])
    for name in inventory_kernels:
        body = new_inventory[name + '_in']['source'].split('\n', 1)[1]
        assert not re.search(r'\bactual\.\w+\(', body), name
        body = body.replace('actual.', '')
        for call in inventory_kernels:
            body = body.replace(call + '_in(actual, ', call + '(').replace(call + '_in(actual)', call + '()')
        assert body == old_inventory[name]['source'].split('\n', 1)[1], name
    print(json.dumps({
        'scope': 'Logical numeric payloads only. Existing Inventory journal, item math and claim banks are reused. Native reference/StringName/Variant headers and interpreter allocations are unmeasured.',
        'base': BASE,
        'source_sha256': {f'godot/scripts/core/{m}.gd': hashlib.sha256(s.encode()).hexdigest() for m, s in source.items()},
        'packet_members': packet, 'packet_bytes': packet_bytes,
        'fixed_bytes': 433, 'fixed_reserve': 512, 'helper_reserve': 512,
        'native_reference_result_provisional_reserve': 2048, 'total_reservation': 3072,
        'outcome_numeric_bytes': outcome_bytes, 'chains': chains, 'maximum_lower_chain': maximum,
        'callback_base_bytes': callback_base, 'callback_base_path': callback_path,
        'foreign_delivery': 'Concrete callback/control lifetime is counted once in Delivery4096; this512 covers the active lower frames and explicit outcome aliases. Final paired census must join both without charging the borrowed Transfer twice.',
        'new_native_references': ['two Transfer RefCounted wrappers', '_haul_inventory strong during original operation', '_haul_guard strong during original operation', '_haul_error StringName'],
        'source_identical_extracted_kernels': extracted,
        'source_identical_inventory_kernels': inventory_kernels,
        'variable_bank_delta': 0,
    }, indent=2))


if __name__ == '__main__':
    main()
