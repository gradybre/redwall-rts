#!/usr/bin/env python3
"""Source-count the stateless clock jointly with the unchanged accepted Motion allowance."""
import hashlib
import re

import underground_motion_memory as motion

FILE = 'godot/scripts/core/underground_motion_clock.gd'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def build(index, baseline):
    source = index['underground_motion_clock'].text
    require(source.startswith('extends RefCounted\n'), 'exact stateless base')
    # The complete tiny executable is closed, not a blacklist of allocation spellings.
    # Any body/declaration change requires an independent recount before this pin changes.
    executable = re.sub(r'""".*?"""', '', source, flags=re.S)
    executable = re.sub(r'#[^\n]*', '', executable)
    executable = '\n'.join(line.rstrip() for line in executable.splitlines() if line.strip())
    require(hashlib.sha256(executable.encode()).hexdigest() == 'ee137604200ba9854a7c11d70314c72486a2b1ff377e677ee1eca8319ef49c0d',
            'complete Clock executable changed; independently recount every allocation and frame')

    require(not re.search(r'^(?:static )?var |^class ', source, re.M), 'no retained fields or classes')
    require(not re.search(r'\.new\(|\.resize\(|\.duplicate\(|\.slice\(|Packed\w+Array\(|\b(?:Array|Dictionary)\[', source),
            'no helper allocation, copy or collection')
    found = motion.functions(source)
    require(set(found) == {'sample_into', '_duration'}, 'complete function census')
    require(source.count('static func ') == 2, 'every helper is stateless')
    numeric_constants = re.findall(r'^const (\w+): int = (\d+)$', source, re.M)
    require(numeric_constants == [('TREAD_TICKS', '30'), ('HALF_TURN_TICKS', '45')], 'adopted numeric constants')
    variants = re.findall(r'\b(\w+): Variant\b', source)
    require(variants == ['revision', 'program', 'from_tick', 'to_tick'], 'exact accepted integer command slots')
    for name in variants:
        require('typeof(' + name + ') != TYPE_INT' in source, 'integer boundary: ' + name)
    require('pose_out.size() != 9 or intervals_out.size() != 2' in source, 'exact caller shape')
    require('motion.phase_into(int(program), int(revision), phase, pose_out)' in source, 'actual source query')
    require('Motion.SOURCE_WIRE_SHA != SOURCE_WIRE_SHA' in source, 'immutable wire contract')
    own = {name: row['numeric'] for name, row in found.items()}
    own['sample_into'] += len(variants) * 8
    own_maximum = own['sample_into'] + own['_duration']
    constants = len(numeric_constants) * 8
    expression_allowance = 128
    addition = own_maximum + constants + expression_allowance
    require(addition <= 256, 'bounded additional scalar/helper allowance')
    phase_chain = baseline['own_chains']['phase_into']['bytes']
    composed_chain = max(own_maximum, own['sample_into'] + phase_chain)
    logical = baseline['logical_and_helper_counted'] + addition
    require(logical <= baseline['logical_helper_reservation'], 'same joint 4096 helper reserve')
    require(44 <= baseline['caller']['maximum_bytes'], 'same caller packet admission')
    return {
        'clock_source_sha256': hashlib.sha256(source.encode()).hexdigest(),
        'motion_source_sha256': baseline['source_sha256'],
        'scope': 'Logical source census only; no native allocation, route or presentation qualification',
        'retained_fields_or_banks': 0, 'accepted_variant_payload_bytes': len(variants) * 8,
        'own_numeric_frames': own, 'maximum_own_numeric_chain': own_maximum,
        'existing_motion_phase_numeric_chain': phase_chain, 'composed_phase_numeric_chain': composed_chain,
        'numeric_constant_bytes': constants, 'additional_expression_allowance': expression_allowance,
        'additional_logical_counted': addition, 'additional_helper_ceiling': 256,
        'existing_motion_logical_counted': baseline['logical_and_helper_counted'],
        'combined_logical_counted': logical, 'combined_with_full_helper_ceiling': baseline['logical_and_helper_counted'] + 256,
        'shared_logical_helper_reservation': baseline['logical_helper_reservation'],
        'clock_caller_bytes': 44, 'shared_caller_reservation': baseline['caller']['maximum_bytes'],
        'joint': baseline['joint'], 'native_measured': False,
        'native_additions_within_existing_provisional_32768': [
            'One shared Script/preload and one 64-character source digest, no instantiated clock',
            'Interned StringNames, two shared numeric constants, and bounded interpreter frames',
            'Four transient Variant command slots (numeric payload counted above; representation overhead remains native)',
            'Borrowed Motion and two caller packed-array handles; no retained or duplicated buffers',
        ],
        'lifetime': 'One synchronous caller; no resident clock. Motion phase frame and clock frame coexist. '
                    'The existing maximum Motion chain is conservatively retained in the total, plus the entire clock-only maximum. '
                    'The clock 44-byte output replaces, rather than adds to, the existing 176-byte caller ceiling.',
    }

