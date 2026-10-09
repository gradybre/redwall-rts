#!/usr/bin/env python3
"""Current joint Motion/Profile/Level source census, enforced by the shared underground pack."""
import ast
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

FILE = 'godot/scripts/core/underground_motion_catalog.gd'
WIDTH = {'int': 8, 'bool': 1, 'Vector2i': 8, 'Vector3i': 12}
EXPECTED = {
    '_live': 'Bank', '_stage': 'Bank', '_profiles': 'Profiles', '_profile_bank': 'Profiles.Bank',
    '_levels': 'Levels', '_directory': 'Directory', '_level_identity': 'PackedInt32Array',
    '_level_config': 'PackedInt32Array', '_level_digest': 'PackedByteArray', '_digest': 'PackedByteArray',
    '_world': 'Vector2i', '_world_pid': 'int', '_profile_revision': 'int', '_level_revision': 'int',
    '_admitted_bytes': 'int', '_revision': 'int', '_busy': 'bool', '_poisoned': 'bool',
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def functions(source):
    lines, result = source.splitlines(), {}
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
        kinds = re.findall(r'\b\w+\s*:\s*(int|bool|Vector2i|Vector3i)\b', executable)
        require(len(body.splitlines()) <= 30, name + ' exceeds30 physical lines')
        result[name] = {'numeric': sum(WIDTH[kind] for kind in kinds), 'code': executable}
    return result


def decoder_lifetime(source):
    """Pin the small chunk call boundary; a packed return temporary may outlive a loop iteration."""
    require(re.search(r'^const DECODE_BYTES: int = 4096$', source, re.M), 'exact decoder window')
    found = functions(source)
    require('_decode_payload' in found, 'scoped decoder chunk required')
    column = found['_decode_column']['code']
    expected_loop = '''\twhile at < count:
\t\t@warning_ignore("integer_division") var span: int = mini(DECODE_BYTES / width, count - at)
\t\tvar code: StringName = _decode_payload(file, hashing, column, at, span, width)
\t\tif code != &"":
\t\t\treturn code
\t\tat += span
\treturn &""'''
    require(column[column.index('\twhile at < count:'):].strip() == expected_loop.strip(),
            'chunk loop must retain only scalar/string results, never a payload alias')
    require(column.count('_read(') == 1 and '_read(file, hashing, 12)' in column,
            'column frame may retain only its fixed 12-byte header')
    payload = '''func _decode_payload(file: FileAccess, hashing: HashingContext, column: int, at: int, span: int, width: int) -> StringName:
\tvar bytes: PackedByteArray = _read(file, hashing, span * width)
\tif bytes.size() != span * width:
\t\treturn &"MOTION_WIRE_TRUNCATED"
\tfor index: int in span:
\t\tif column == 0:
\t\t\t_stage.ints[at + index] = bytes.decode_s32(index * width)
\t\telif column == 1:
\t\t\t_stage.longs[at + index] = bytes.decode_s64(index * width)
\t\telse:
\t\t\t_stage.bytes[at + index] = bytes[index]
\treturn &""'''
    actual_payload = '\n'.join(line for line in found['_decode_payload']['code'].splitlines() if line.strip())
    require(actual_payload == payload, 'payload frame must copy scalars only and return no packed alias')
    expected_read = '''static func _read(file: FileAccess, hashing: HashingContext, count: int) -> PackedByteArray:
\tvar bytes: PackedByteArray = file.get_buffer(count)
\thashing.update(bytes)
\treturn bytes'''
    actual_read = '\n'.join(line for line in found['_read']['code'].splitlines() if line.strip())
    require(actual_read == expected_read, 'stream read must return one borrowed buffer without a retained copy')
    return {'maximum_requested_bytes': 4096, 'maximum_simultaneous_payload_windows': 1,
            'other_headers_charged_above': True,
            'lifetime': 'Each _decode_payload frame owns every packed alias and returns only StringName; its frame ends before the next chunk call. No loop-local packed payload, full wire, JSON or to_byte_array copy. Hashing borrows the same payload.'}


def build(index):
    # Lazy import avoids a circular initialization when the shared pack invokes this census.
    import underground_memory_budget as memory
    source = index['underground_motion_catalog'].text
    require(source.startswith('extends RefCounted\n'), 'exact stateless base')
    require(memory.explicit_members(source) == EXPECTED, 'complete explicit owner members')
    bank = memory.class_body(source, 'Bank')
    require('class Bank extends RefCounted:' in source, 'exact Bank base')
    require(memory.explicit_members(bank, '\t') == {'ints': 'PackedInt32Array', 'longs': 'PackedInt64Array', 'bytes': 'PackedByteArray'}, 'three exact bank columns')
    bank_sizes = {'I32_COUNT': (17421, 4), 'I64_COUNT': (67, 8), 'BYTE_COUNT': (640, 1)}
    for constant, (count, _) in bank_sizes.items():
        require(re.search(r'^const ' + constant + r': int = ' + str(count) + r'$', source, re.M), constant)
    require(re.findall(r'\b(ints|longs|bytes)\.resize\((\w+)\)', bank) == [
        ('ints', 'I32_COUNT'), ('longs', 'I64_COUNT'), ('bytes', 'BYTE_COUNT')], 'one resize per bank column')
    require(source.count('Bank.new()') == 2 and source.count('_live.allocate()') == 1 and source.count('_stage.allocate()') == 1, 'exact paired constructor/allocator count')
    control_arrays = {'_level_identity': 21*4, '_level_config': 13*4, '_level_digest': 32, '_digest': 32}
    require(re.findall(r'(_level_identity|_level_config|_level_digest|_digest)\.resize\((\d+)\)', source) == [
        ('_digest', '32'), ('_level_identity', '21'), ('_level_config', '13'), ('_level_digest', '32')], 'one resize per control')
    numeric = {name: WIDTH[kind] for name, kind in EXPECTED.items() if kind in WIDTH}
    fixed = sum(control_arrays.values()) + sum(numeric.values())
    require(fixed == 250, 'actual fixed owner numeric/packed payload')
    constants = {name: ast.literal_eval(values) for name, values in re.findall(r'^const (\w+): Array\[int\] = (\[[^\n]+\])$', source, re.M)}
    require(set(constants) == {'GAIT_BASE', 'GAIT_ROWS', 'HANDOFF_BASE', 'HANDOFF_ROWS', 'HEADER', 'BOUNDS'}, 'all shared numeric constants')
    constant_bytes = sum(len(values)*8 for values in constants.values())
    require(constant_bytes == 432, 'shared constant numeric payload charged once conservatively per owner')
    found = functions(source)

    def children(name):
        return {call for receiver, call in re.findall(r'(?:(\b\w+)\.)?\b(\w+)\s*\(', found[name]['code'])
                if not receiver and call in found and call != name}

    def longest(name, seen=()):
        options = [longest(child, (*seen, name)) for child in children(name) if child not in seen]
        best = max(options, key=lambda value: (value[0], value[1])) if options else (0, [])
        return found[name]['numeric'] + best[0], [name] + best[1]

    entries = [name for name in found if not name.startswith('_')]
    chains = {}
    for entry in entries:
        count, path = longest(entry)
        chains[entry] = {'bytes': count, 'path': path, 'frames': {name: found[name]['numeric'] for name in path}}
    maximum = max(row['bytes'] for row in chains.values())
    # Count headers, source-validation digests and the two-element cold loop literal in addition
    # to all declared numeric frames. These are conservative simultaneous maxima, not native sizes.
    transient_payload = 32 + 12 + 8 + 4 + 64 + 16
    expression_allowance = 128
    logical = fixed + constant_bytes + maximum + transient_payload + expression_allowance
    require(logical <= 4096, 'complete logical/helper reservation')
    derived = joint_sources(index, memory)
    profile = derived['profile_bytes']
    level = derived['level_bytes']
    one_bank = sum(count*width for count, width in bank_sizes.values())
    joint = profile + level + 2*one_bank + 4096 + 176 + 4096 + 32768
    maximum_profiles = derived['maximum_profile_bytes']
    maximum_joint = joint - profile + maximum_profiles
    require((profile, one_bank, joint, maximum_joint) == (51992, 70860, 237140, 444284), 'exact joint formula')
    require(joint <= 262144 < maximum_joint, 'configured coexistence, no independent maxima')
    return {
        'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
        'status': 'SOURCE_COUNTED_COMPONENT_ONLY; no native allocation or travel/timing qualification',
        'bank_members': {'ints': [17421, 4], 'longs': [67, 8], 'bytes': [640, 1]},
        'one_bank_bytes': one_bank, 'paired_bank_bytes': 2*one_bank,
        'control_arrays': control_arrays, 'numeric_members': numeric, 'fixed_owner_payload': fixed,
        'shared_constant_elements': {name: len(values) for name, values in constants.items()},
        'shared_constant_payload_conservatively_charged_per_owner': constant_bytes,
        'own_chains': chains, 'maximum_own_declared_numeric_chain': maximum,
        'simultaneous_small_payload_allowance': transient_payload, 'expression_result_allowance': expression_allowance,
        'logical_and_helper_counted': logical, 'logical_helper_reservation': 4096,
        'decode': decoder_lifetime(source),
        'caller': {'maximum_bytes': 176, 'lifetime': 'One caller packet: largest single header160 or descriptor136. A descriptor136 plus phase36 plus one4-byte counter is176. No per-actor copy.'},
        'native_provisional_reservation': 32768,
        'native_inventory': ['Motion RefCounted + two Bank wrappers', 'ten retained packed-array handles',
                             'six retained borrowed owner/Bank references', 'seven shared constant Array handles with54integer+3String elements',
                             'five shared64-character digest strings plus interned code constants',
                             'one FileAccess and one HashingContext during load',
                             'bounded header/slice/string/digest temporaries and interpreter frames'],
        'native_measured': False,
        'foreign_call_lifetime': 'MoleCatalog runtime source hashing and exact Profile wire check run sequentially before decoding. Their existing32KiB Profiles control reserve is included once in51992, not additionally allocated. Actual Content palettes in tests have separate declared presentation reservation; none is retained by Motion.',
        'profile_configuration': derived['configuration'],
        'joint': {'profiles': profile, 'levels': level, 'paired_motion': 2*one_bank, 'decode': 4096, 'caller': 176,
                  'logical_helper': 4096, 'native': 32768, 'total': joint, 'reservation': 262144, 'headroom': 262144-joint,
                  'independent_maxima_total_refuses': maximum_joint},
        'admission_limit': 'This component assumes a single caller-owned composed source catalog. Root owns shared reservation enforcement; constructing arbitrary extra owners is not an admitted World configuration.',
    }


def joint_sources(index, memory):
    """Check actual column widths and allocators, not only the Motion formula's literal constants."""
    profile = index['underground_profiles'].text
    bank = memory.class_body(profile, 'Bank')
    require(memory.explicit_members(bank, '\t') == {
        'header': 'PackedInt64Array', 'fields': 'PackedInt32Array', 'quantities': 'PackedInt64Array',
        'flags': 'PackedByteArray', 'boxes': 'PackedInt32Array', 'sources': 'PackedByteArray'}, 'complete Profile bank')
    require(re.findall(r'\b(header|fields|quantities|flags|boxes|sources)\.resize\(([^)]+)\)', bank) == [
        ('fields', 'profiles * I32_FIELDS'), ('quantities', 'profiles * I64_FIELDS'),
        ('flags', 'profiles * BYTE_FIELDS'), ('boxes', 'volumes * 7'), ('sources', 'bundles * 32')],
        'exact Profile allocation cardinality')
    require('PackedInt64Array([0, 0, 0, 0])' in bank, 'exact Profile header')
    require(profile.count('Bank.new()') == 2 and profile.count('.allocate(profiles, boxes, sources)') == 2,
        'one actual paired Profile allocation')
    constants_index = dict(index)
    for name in ('underground_profiles', 'underground_level_catalog', 'underground_motion_catalog',
                 'underground_budget', 'mole_profile_catalog'):
        original = index[name]
        constants_source = re.sub(r'(?m)^(const \w+: int = [^#\n]+)#[^\n]*$', r'\1', original.text)
        constants_index[name] = memory.audit.parse_module(name, original.relative_path, constants_source)
    resolve = lambda module, value: memory.resolve(constants_index, module, value)
    per_profile = sum(resolve('underground_profiles', key) * width for key, width in (
        ('I32_FIELDS', 4), ('I64_FIELDS', 8), ('BYTE_FIELDS', 1)))
    require(per_profile == resolve('underground_profiles', 'PROFILE_WIRE_BYTES') == 98, 'Profile row width')
    catalog = index['mole_profile_catalog']
    counts = (resolve(catalog.name, 'PROFILE_COUNT'), resolve(catalog.name, 'BOX_COUNT'), 1)
    require(counts == (26, 250, 1), 'current accepted publication configuration')
    control = resolve('underground_profiles', 'CONTROL_RESERVE')
    require(control == 32768, 'Profile helper/native envelope unchanged')
    level = resolve('underground_level_catalog', 'RESERVED_BYTES')
    require(level == 2292, 'Level retained/control envelope unchanged')
    maximum = tuple(resolve('underground_profiles', key) for key in ('MAX_PROFILES', 'MAX_BOXES', 'MAX_SOURCES'))
    size = lambda values: 2 * (values[0] * per_profile + values[1] * 28 + values[2] * 32 + 32) + control
    motion = index['underground_motion_catalog'].text
    formula = ('return 2 * (98 * p + 28 * b + 32 * s + 32) + Profiles.CONTROL_RESERVE + Levels.RESERVED_BYTES '
               + chr(92) + '\n\t\t+ 2 * BANK_BYTES + DECODE_BYTES + CALLER_BYTES + CONTROL_BYTES + NATIVE_RESERVE')
    require(formula in motion, 'actual runtime joint formula')
    for constant, expected in {'BANK_BYTES': 70860, 'DECODE_BYTES': 4096, 'CALLER_BYTES': 176,
                               'CONTROL_BYTES': 4096, 'NATIVE_RESERVE': 32768}.items():
        require(resolve('underground_motion_catalog', constant) == expected, 'Motion reserve: ' + constant)
    require(resolve('underground_budget', 'PROFILE_BYTES') == 262144, 'unchanged shared PROFILE_BYTES')
    require(resolve('underground_profiles', 'ARENA_BYTES') == 262144, 'unchanged Profile admission ceiling')
    return {'profile_bytes': size(counts), 'level_bytes': level, 'maximum_profile_bytes': size(maximum),
            'configuration': dict(zip(('profiles', 'boxes', 'sources'), counts))}
