#!/usr/bin/env python3
"""Confirm UI accounting consumes a changed indexed Host frame without file edits."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent


def check(root):
    pins = json.loads((HERE / 'repair-pass-1/source-before.json').read_text())
    for path, expected in pins.items():
        if hashlib.sha256((root / path).read_bytes()).hexdigest() != expected:
            raise ValueError('reviewed shared source changed: ' + path)
    sys.path.insert(0, str(root / 'tools'))
    import underground_memory_budget as budget
    index = budget.audit.load_source_index()
    path = 'godot/scripts/systems/settlement_system.gd'
    name = 'settlement_system'
    original = budget.audit.parse_module(name, path, (root / path).read_text())
    index[name] = original
    base = budget.build(index)
    needle = 'func abandon_world_reset() -> bool:\n'
    if original.text.count(needle) != 1:
        raise ValueError('exact source probe location changed')
    changed = original.text.replace(needle, needle + '\tvar reviewer_frame_probe: int = 0\n', 1)
    index[name] = original._replace(text=changed)
    mutant = budget.build(index)
    frame = 'Host.abandon_world_reset'
    before = base['ui_reset_reservation']['frames'][frame]['numeric_and_name_bytes']
    after = mutant['ui_reset_reservation']['frames'][frame]['numeric_and_name_bytes']
    if after != before + 8:
        raise AssertionError('current indexed Host frame did not reach UI composition')
    for path, expected in pins.items():
        if hashlib.sha256((root / path).read_bytes()).hexdigest() != expected:
            raise ValueError('shared source drifted during review: ' + path)
    return {'scope': 'In-memory indexed source mutation only; no GDScript or engine execution.',
            'cached_host_sha_left_unchanged': original.sha256 == index[name].sha256,
            'ui_composed_host_frame_before': before, 'ui_composed_host_frame_after': after,
            'current_index_used_in_ui_composition': True,
            'control_bytes': base['ui_reset_reservation']['accounting']['controls'],
            'helper_bytes': base['ui_reset_reservation']['accounting']['helpers'],
            'global_total': base['live_with_reserve_bytes'], 'global_headroom': base['headroom_bytes'],
            'joint': base['ui_reset_reservation']['accounting']['profile_joint_unchanged'],
            'runtime_qualified': base['runtime_qualified']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(check(args.root.resolve()), indent=2))
