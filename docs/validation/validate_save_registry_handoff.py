#!/usr/bin/env python3
"""Check the declared registry and independent contract fixtures, not Godot saves."""
import argparse
import importlib.util
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def validate_registry(data):
    owners = data['owners']
    keys = [(o['section_id'], o['owner_key']) for o in owners]
    assert keys == sorted(set(keys)), 'duplicate or unordered owner'
    records = 0
    bindings = set()
    for owner in owners:
        assert 1 <= owner['section_id'] <= 14
        assert owner['owner_schema_version'] >= 1
        key = owner['owner_key']
        assert key and key.isascii() and len(key.encode()) <= 256
        seen = set()
        for ordinal, field in enumerate(owner['fields']):
            assert field['ordinal'] == ordinal
            key = field['field_key']
            assert key and key.isascii() and len(key.encode()) <= 256 and key not in seen
            seen.add(key)
            assert {'u8':0,'u32':1,'i32':2,'u64':3,'i64':4,'utf8_u32':5}[field['type']] == field['type_code']
            records += int(field['hash'])
            bindings.add((field['source_module'], field['source_member']))
            if 'count_field' in field['shape']:
                assert any(f['field_key'] == field['shape']['count_field'] and f['ordinal'] < ordinal for f in owner['fields'])
            if 'source_contract' in field:
                assert field['source_contract'] in data['source_contracts']
    # 564 was the 197472b snapshot. REG-R01 requires the declaration to grow when concurrent
    # state lands, so this pin moves WITH a reconciliation and is not a constant of the format:
    # +18 for needs._airless, work's six tool-settlement columns and injury's eleven.
    # 582 -> 599 because construction.gd's SEVENTEEN category-1 columns had never been declared
    # at all -- they are seventeen NEW hash=true declarations, so they are seventeen new records.
    # Contrast section 11, which moved packed_source_field_count and NOT this, because those
    # eight fields were already declared and only acquired a source module.
    assert records == data['record_count'] == 599
    directory = next(o for o in owners if (o['section_id'],o['owner_key']) == (3,'entity_directory'))
    assert [f['field_key'] for f in directory['fields']] == ['_active','_generation','_retired','_persistent_id','_kind','_typed_row']
    allocator = next(o for o in owners if (o['section_id'],o['owner_key']) == (1,'entity_directory'))
    assert [(f['field_key'],f['type']) for f in allocator['fields']] == [('_next_persistent_id','u32')]
    world = next(o for o in owners if o['owner_key'] == 'world_runtime')
    assert [f['field_key'] for f in world['fields'] if f['hash']] == ['_world_seed','_seeded','_requested_speed','_pause_mask']
    for section, key, first, later in [(4,'transforms','_bound_persistent_id','_x'),(7,'inventory','_c_generation','_c_owner_slot'),(9,'navigation','_d_flags','_d_route_id'),(9,'navigation','_stamp','_g')]:
        owner=next(o for o in owners if (o['section_id'],o['owner_key'])==(section,key))
        order={f['field_key']:f['ordinal'] for f in owner['fields']}
        assert order[first]<order[later], (key,first,later)
    return bindings

def validate_source(data, source):
    spec=importlib.util.spec_from_file_location('source_registry',source/'docs/validation/state_registry_coverage.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    assert mod.main() == 0, 'source classification registry failed'
    actual={}
    for module, rows in mod.REGISTRY_ROWS.items():
        for row in rows:
            if row['cells'][5] == '1':
                for member in mod.row_members(module,row):
                    actual[(module,member)] = mod.MODULES[module]['columns'][member]
    declared={}
    for owner in data['owners']:
        for field in owner['fields']:
            if 'source_contract' in field:
                declared[(field['source_module'],field['source_member'])]=field
    assert actual.keys() == declared.keys(), f'packed registry drift: added={actual.keys()-declared.keys()}, missing={declared.keys()-actual.keys()}'
    mapped={'PackedByteArray':{'u8'},'PackedInt32Array':{'i32','u32'},'PackedInt64Array':{'i64','u64'},'PackedStringArray':{'utf8_u32'}}
    for key,typ in actual.items():assert declared[key]['type'] in mapped[typ], key
    # 512 was the 197472b snapshot; the same REG-R01 growth rule applies here as to record_count.
    # 530 -> 536 when event_schedule.gd landed section 11's six record columns. This pin is a
    # snapshot, NOT a format constant: REG-R01 requires it to grow, so moving it is the expected
    # maintenance and freezing it would refuse every new store.
    # 536 -> 553 on registering construction.gd's seventeen already-implemented category-1
    # columns: sixteen project columns in section 4 and the delivered-material arena in section 5.
    # That omission is exactly the drift the assertion above is here to catch.
    assert len(actual)==data['packed_source_field_count']==553
    print(f"PASS source membership/types: {len(actual)} persisted packed fields (not semantic adapter validation)")

def valid_name(present, named, raw):
    try: text=raw.decode('utf-8','strict')
    except UnicodeDecodeError:return False
    if named not in (0,1) or present not in (0,1):return False
    if not present:return named == 0 and text == ''
    if not named:return text == ''
    return (len(raw)<=128 and 2<=len(text)<=32 and
            all(ord(c)>31 and not 127<=ord(c)<=159 for c in text))

def contract_fixtures():
    cases=[(1,0,b'',True),(0,0,b'',True),(1,1,b'',False),(1,0,b'Oak',False),
           (0,1,b'Oak',False),(1,1,b'A',False),(1,1,b'Ab',True),
           (1,1,b'A'*32,True),(1,1,b'A'*33,False),(1,1,b'A'*40,False),
           (1,1,'Móle'.encode(),True),(1,1,('🐭'*32).encode(),True),
           (1,1,('🐭'*33).encode(),False),(1,1,b'A\x00b',False),
           (1,1,b'A\x7fb',False),(1,1,'A\u0085b'.encode(),False),
           (1,1,b'\xc0\x80',False),(1,1,b'\xed\xa0\x80',False),
           (1,1,'e\u0301'.encode(),True)]
    for present,named,raw,expected in cases:assert valid_name(present,named,raw)==expected,(present,named,raw)
    assert struct.pack('<I',2147483648).hex() == '00000080'
    valid_cursor=lambda cursor,ids: 1<=cursor<=2147483648 and all(cursor>x for x in ids if x>0)
    for cursor,ids,expected in [(4,[1,2],True),(4,[],True),(2147483648,[2147483647],True),(0,[],False),(2147483649,[],False),(2,[1,2],False)]:
        assert valid_cursor(cursor,ids)==expected
    assert 4+512*(4+128)==67588
    assert 4+(4+len('residents')+4+8+8)+67588==67625
    for value,want in [('', '00000000'),('Oak','030000004f616b'),('Móle','050000004dc3b36c65')]:
        raw=value.encode();assert (struct.pack('<I',len(raw))+raw).hex()==want
    print('PASS 31 independent name, cursor, UTF-8 framing and name-section-bound fixtures')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-root',type=Path);ap.add_argument('--require-release-ready',action='store_true');args=ap.parse_args()
    data=json.loads((ROOT/'docs/planning/canonical_state_registry.json').read_text())
    validate_registry(data);contract_fixtures()
    if args.source_root:validate_source(data,args.source_root)
    print(f"PASS registry structure: {len(data['owners'])} owners, {data['record_count']} canonical records")
    if args.require_release_ready and not data['release_save_ready']:
        print('REFUSED: release save not ready; see explicit release_blockers in registry')
        return 2
    return 0

if __name__=='__main__':raise SystemExit(main())
