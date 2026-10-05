#!/usr/bin/env python3
"""1173 exact metadata/source-map delta and simultaneous inherited Profile/Motion admission."""
from __future__ import annotations
import hashlib
import ast
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[4]
E = Path(__file__).resolve().parent
BASELINE_SHA = '06a18674b7ed86abd429323eeffe81efb9a65bc70b66f285e6d27379115824ff'
CATALOG = 'godot/data/underground/mole-worker/mole_profile_catalog.gd'
MOTION = 'godot/scripts/core/underground_motion_catalog.gd'
CLOCK = 'godot/scripts/core/underground_motion_clock.gd'
COMPOSITION = 'godot/scripts/core/underground_route_composition.gd'
P = 'godot/data/underground/mole-worker/qualified-step-v4/'
OLD_MOTION = '2f44037e5e4eed0b4e2966cd1ac1881bdf4481dd083a26b11d8eea0c5ca0f986'
NEW_MOTION = '69fd9011da9b9c1d85e206401ef287943381a24d19322946287234b2dc66850c'
OLD_GROUND = '1880788c064b87424c203509a7ad65498b9d11fc18842affe909364b8a8aca4a'
NEW_GROUND = '454eaab1b2a722aab2700285d31a0bcc093312dad211208da7993baa32bc2f24'


def need(ok, message):
    if not ok: raise ValueError(message)


def sha(raw): return hashlib.sha256(raw).hexdigest()


def replace_once(text, before, after):
    need(text.count(before) == 1, 'original source seam: ' + before)
    return text.replace(before, after)


def integer(source, name):
    found = re.findall(r'^const ' + re.escape(name) + r': int = ([^#\n]+)(?:#.*)?$', source, re.M)
    need(len(found) == 1, 'one exact numeric constant: ' + name)
    def resolve(node):
        if isinstance(node, ast.Constant) and type(node.value) is int: return node.value
        if isinstance(node, ast.Name): return integer(source, node.id)
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add): return resolve(node.left)+resolve(node.right)
        raise ValueError('unsupported constant expression: '+name)
    return resolve(ast.parse(found[0].strip(),mode='eval').body)


def executable(source):
    text = re.sub(r'""".*?"""', '', source, flags=re.S)
    text = re.sub(r'#[^\n]*', '', text)
    return '\n'.join(line.rstrip() for line in text.splitlines() if line.strip())


def build(overrides=None):
    overrides = overrides or {}
    baseline_bytes = (E/'baseline.json').read_bytes()
    need(sha(baseline_bytes) == BASELINE_SHA, 'immutable predecessor manifest')
    record = json.loads(baseline_bytes)
    sources, old = {}, {}
    for name, row in record['sources'].items():
        raw = (ROOT/row['locator']).read_bytes()
        need(sha(raw) == row['sha256'], 'immutable predecessor source: '+name)
        old[name] = raw.decode()
        sources[name] = overrides.get(name, (ROOT/name).read_text())
    expected = old[CATALOG]
    for before, after in [('Nine borrowed','Ten borrowed'),('profile-publication-v3-frontier','qualified-step-v4'),
        ('PROFILE_COUNT: int = 26','PROFILE_COUNT: int = 29'),('BOX_COUNT: int = 250','BOX_COUNT: int = 271'),
        ('CONTENT_REVISION: int = 2','CONTENT_REVISION: int = 3'),('WIRE_BYTES: int = 9620','WIRE_BYTES: int = 10502'),
        ('PAIRED_BANK_BYTES: int = 19224','PAIRED_BANK_BYTES: int = 20988'),
        ('Pins.PATHS.size() != 9 or Pins.DIGESTS.size() != 9','Pins.PATHS.size() != 10 or Pins.DIGESTS.size() != 10'),
        ('for index: int in 9:', 'for index: int in 10:'),
        ('return 10 + 4 * heading', 'return 13 + 4 * heading'),
        ('index if index < 2 else index + 8','index if index < 2 else index + 11')]:
        need(before in expected, 'old Catalog seam: '+before); expected=expected.replace(before, after)
    added = '''static func canonical_ground_profile_id() -> int:
	"""Explicit canonical admission opts into Routes' integer source clock; legacy WALK remains row one."""
	return 12


static func short_step_profile_id(yaw: int, backward: bool = false) -> int:
	"""Only the source-proved positive-X body heading has this finite232u protocol."""
	return (11 if backward else 10) if yaw == 49152 else -1


'''
    expected = replace_once(expected,'static func pins_into(', added+'static func pins_into(')
    need(sources[CATALOG] == expected, 'Catalog exact accepted allocation/call/field boundary')
    expected = old[MOTION]
    for before, after in [('profile-publication-v3/catalog_source.gd','qualified-step-v4/catalog_source.gd'),
        (OLD_MOTION,NEW_MOTION),('HEADER: Array[int] = [1, 2, 2,','HEADER: Array[int] = [1, 3, 3,'),
        ('revision != 2','revision != 3'),('bytes.decode_s64(16) != 2','bytes.decode_s64(16) != 3'),
        ('_revision = 2','_revision = 3')]: expected=replace_once(expected,before,after)
    need(sources[MOTION] == expected, 'Motion is metadata-only; no field/bank/call/decoder changes')
    need(sources[CLOCK] == replace_once(old[CLOCK],OLD_MOTION,NEW_MOTION), 'Clock is digest-only')
    expected = old[COMPOSITION]
    for before, after in [('PROFILE_CONTENT_REVISION: int = 2','PROFILE_CONTENT_REVISION: int = 3'),
        ('res://data/underground/ground-pace-v1/ground-pace.ugconn','res://data/underground/mole-worker/qualified-step-v4/ground-pace.ugconn'),
        (OLD_GROUND,NEW_GROUND),('catalog._live.header[7] != 9','catalog._live.header[7] != 12')]: expected=replace_once(expected,before,after)
    for before, after in zip(struct.unpack('<4q',bytes.fromhex(OLD_GROUND)),struct.unpack('<4q',bytes.fromhex(NEW_GROUND))):
        expected=replace_once(expected,str(before),str(after))
    need(sources[COMPOSITION] == expected, 'Composition is source-identity-only; no new lifetime')
    # Read actual current constants. Retained successor banks and the original caller/native allowances coexist once.
    catalog, motion = sources[CATALOG], sources[MOTION]
    profiles = (ROOT/'godot/scripts/core/underground_profiles.gd').read_text()
    levels = (ROOT/'godot/scripts/core/underground_level_catalog.gd').read_text()
    session = (ROOT/'godot/scripts/core/underground_session.gd').read_text()
    retirement = (ROOT/'godot/scripts/core/underground_world_retirement.gd').read_text()
    need(integer(profiles,'I32_FIELDS')*4+integer(profiles,'I64_FIELDS')*8+integer(profiles,'BYTE_FIELDS') == 98,'actual Profile row width')
    need(integer(profiles,'CONTROL_RESERVE') == integer(catalog,'CONTROL_RESERVE') == 32768,'same existing Profile controls')
    paired = 2*(98*integer(catalog,'PROFILE_COUNT')+28*integer(catalog,'BOX_COUNT')+32+32)
    need(paired == integer(catalog,'PAIRED_BANK_BYTES') == 20988,'current paired actual capacity')
    need(4*integer(motion,'I32_COUNT')+8*integer(motion,'I64_COUNT')+integer(motion,'BYTE_COUNT') == integer(motion,'BANK_BYTES') == 70860,'same complete Motion bank')
    terms={'paired_profiles':paired,'profile_controls':integer(catalog,'CONTROL_RESERVE'),
        'levels':integer(levels,'RESERVED_BYTES'),'paired_motion':2*integer(motion,'BANK_BYTES'),
        'motion_decode':integer(motion,'DECODE_BYTES'),'motion_caller':integer(motion,'CALLER_BYTES'),
        'motion_helpers':integer(motion,'CONTROL_BYTES'),'motion_native_provisional':integer(motion,'NATIVE_RESERVE'),
        'session_controls':integer(session,'CONTROL_BYTES'),'session_helpers':integer(session,'HELPER_BYTES'),
        'retirement_composition':integer(retirement,'RETIREMENT_RESERVED_BYTES')}
    need(sum(terms.values()) == 248632 and terms['retirement_composition']==8192,'full existing joint reserve')
    constants = (ROOT/(P+'catalog_source.gd')).read_text()
    paths = re.findall(r'"(res://[^"\n]+)"',constants)
    digests = re.findall(r'^\t"([0-9a-f]{64})",$',constants,re.M)
    need(len(paths)==len(digests)==10,'exact ten borrowed source identity rows')
    named_digests = re.findall(r'^const \w+: String = "([0-9a-f]+)"$',constants,re.M)
    source_strings = sum(map(len, paths+digests+named_digests))*4
    # These immutable metadata Strings and hashing scratch are inside the already counted Profile controls.
    hash_chunks = integer(catalog,'HASH_CHARS')*4*2
    descriptor_and_wire = 184+98+32+28+28
    scalar_and_native_headroom = 32768-source_strings-hash_chunks-descriptor_and_wire
    need(scalar_and_native_headroom > 12000,'fixed source metadata and sequential bounded hashing stay in existing control envelope')
    return {'schema':1,'source_sha256':{name:sha(text.encode()) for name,text in sources.items()},
        'profile_count':29,'box_count':271,'source_count':1,'paired_profile_delta':1764,
        'retained_owner_fields_delta':0,'runtime_bank_count_delta':0,'driver_pin_scalars':54,
        'new_helpers_numeric_frames':{'canonical_ground_profile_id':0,'short_step_profile_id':9},
        'new_helpers_calls_or_allocations':0,'clock_executable_sha256':sha(executable(sources[CLOCK]).encode()),
        'motion_bank_bytes':70860,'motion_source_only':True,'clock_algorithm_unchanged':True,
        'terms':terms,'joint':sum(terms.values()),'reservation':262144,'remaining':262144-sum(terms.values()),
        'catalog':{'cached_consumers':10,'source_metadata_utf32_payload':source_strings,'simultaneous_hash_chunk_payload':hash_chunks,
            'conservative_descriptor_wire_payload':descriptor_and_wire,'remaining_for_existing_scalars_and_native_headers':scalar_and_native_headroom,
            'lifetime':'Ten immutable path/hash rows; cached Scripts are borrowed. Source hash and full Profile hash run sequentially. Existing caller and native controls stay charged once.'},
        'native_measured':False,'world_activation_qualified':False,
        'scope':'Exact source delta from immutable predecessor; no new decoder, object bank, rate or permission. Root separately renews shared checker and whole-pack output.'}


if __name__ == '__main__': print(json.dumps(build(),indent=2))
