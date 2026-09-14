#!/usr/bin/env python3
"""Check Cycle 1 planning arithmetic and handoff wiring; not runtime save parity."""
import copy
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def verify_world(m):
    s=m['section']; owners=s['owners']
    expected=['buildings','entity_directory','farming','forage','resource_nodes','spatial_world','weather','world_init','world_runtime']
    assert [o['owner_key'] for o in owners]==expected
    assert s['section_schema_version']==3 and s['store_count']==9
    widths={'i32':4,'i64':8,'u8':1,'u32':4,'u64':8}
    primary=[16384,1,16384,16384,16384,262144,1,16384,1]
    payloads=[196632,4,737360,65544,65544,2621484,64,65697,80]
    offset=48; fields=0
    for o,n,size in zip(owners,primary,payloads):
        assert o['primary_count']==n
        assert o['owner_schema_version']==(2 if o['owner_key']=='resource_nodes' else 1)
        fields+=len(o['fields'])
        if o['payload_format']=='ordinary_columns':
            p=0
            for ordinal,f in enumerate(o['fields']):
                assert f['ordinal']==ordinal and type(f['element_count']) is int and f['element_count']>0
                assert f['type_width_bytes']==widths[f['type']]
                assert f['count_prefix_bytes']==8 and f['count_offset_in_payload']==p
                assert f['value_offset_in_payload']==p+8
                assert f['value_bytes']==f['element_count']*widths[f['type']]
                p+=8+f['value_bytes']
            assert p==size
        assert o['payload_bytes']==size
        assert o['wrapper_bytes']==24+len(o['owner_key'].encode('ascii'))
        assert o['block_offset_in_section']==offset
        offset+=o['wrapper_bytes']
        assert o['payload_offset_in_section']==offset
        offset+=size
        assert o['end_offset_in_section']==offset
    assert fields==44 and offset==3752768
    assert sum(primary)==344067 and 256+15*64+offset==3753984
    assert [f['field_key'] for f in owners[4]['fields']]==['_resource_slot']
    return True

def main():
    m=json.loads((ROOT/'docs/planning/astra_cycles/cycle_01_world_schema.json').read_text())
    verify_world(m)
    # Bad shape, owner presence/order, and extent changes must fail this target checker.
    mutations=[]
    x=copy.deepcopy(m);x['section']['owners'][6]['primary_count']=512;mutations.append(x)
    x=copy.deepcopy(m);x['section']['owners'][0]['fields'][0]['element_count']=16383;mutations.append(x)
    x=copy.deepcopy(m);x['section']['owners'].pop();mutations.append(x)
    x=copy.deepcopy(m);x['section']['owners'][0],x['section']['owners'][1]=x['section']['owners'][1],x['section']['owners'][0];mutations.append(x)
    for x in mutations:
        try:verify_world(x)
        except AssertionError:pass
        else:raise AssertionError('invalid planning schema accepted')
    # Re-derive the roots from GDD's hall, tile and land contracts, not float conversion.
    tiles=[]
    for p in range(1,13):
        x=57+p;z=69
        assert 58<=x<70 and z==59+10
        assert z>15 and not (76<=x<=78) and (x-100)**2+(z-66)**2>14**2
        assert (2048*x+1024,512,2048*z+1024)==(119808+2048*(p-1),512,142336)
        assert z*128+x==8889+p
        tiles.append(z*128+x)
    assert len(set(tiles))==12
    # Target is deliberately distinct from the active registry.
    assert m['runtime_import_permitted'] is False and m['active_registry_mutation_performed'] is False
    q=json.loads((ROOT/'docs/planning/work_queue.json').read_text())
    items=json.loads((ROOT/'docs/rulings/requests/open_items.json').read_text())
    assert len([i for i in items['items'] if i['blocks']])==3
    answered={i['anchor']:i for i in items['answered']}
    for key in ['w2-section-1-owners-without-encoders','resident-spawn-positions-and-the-pose-scaffold']:
        assert key in answered and not answered[key]['implementation_complete']
        path,anchor=answered[key]['ruling'].split('#')
        assert f'id="{anchor}"' in (ROOT/path).read_text()
    spec=importlib.util.spec_from_file_location('dispatch',ROOT/'tools/dispatch_plan.py')
    dispatch=importlib.util.module_from_spec(spec);spec.loader.exec_module(dispatch)
    approvals=json.loads((ROOT/'docs/planning/art_approvals.json').read_text())
    assert dispatch.validate(q,approvals)==[]
    planned={t['id'] for t in dispatch.plan(q,approvals)['dispatch']}
    assert 'BASELINE-INTEGRATION' in planned and 'SAVE-CAPTURE' not in planned
    assert 'ART-CREATURES' not in planned and 'ART-UI-12' not in planned
    text=(ROOT/'docs/rulings/requests/OPEN.md').read_text()
    for i in items['items']:assert text.count(f'id="{i["anchor"]}"')==1
    packet=(ROOT/'docs/planning/review_packet.md').read_text()
    assert 'Missing declarations are unknown, not approval.' in packet
    assert 'No nonempty declarations found' not in packet or 'does not establish' in packet
    print('PASS Cycle 1: nine-owner wire arithmetic; four malformed target refusals; twelve starter-root fixtures; archived answers; queue gates; stable inbox anchors; packet evidence limits.')
    print('Scope: planning consistency only; no production codec, physical clearance, art or save-continuation acceptance.')
    return 0

if __name__=='__main__':raise SystemExit(main())
