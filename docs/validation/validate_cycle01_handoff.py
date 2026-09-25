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
    # Preserve the historical Cycle1 file-position proof; SAVE-REPLAY-R01 relocates it by8.
    assert sum(primary)==344067 and 256+15*64+offset==3753984
    # This second arithmetic is the live format2 runtime file position.
    assert 264+15*64+offset==3753992
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
    # This used to assert the LIVE blocking count was 3 -- a Cycle 1 snapshot. Cycles 2 and 3
    # then answered items, which is what cycles are for, and this validator failed from that
    # moment. It is not in CI, so nothing noticed until a manual sweep of merged master.
    #
    # A cycle's validator must check ITS OWN claims, not a number later cycles are supposed to
    # move. What is durable about Cycle 1 is that the two questions it answered are recorded as
    # answered and are no longer blocking anything; the size of the live inbox is Cycle 3's
    # business and Cycle 4's, not Cycle 1's.
    blocking_anchors = {i['anchor'] for i in items['items'] if i['blocks']}
    for settled in ['w2-section-1-owners-without-encoders',
                    'resident-spawn-positions-and-the-pose-scaffold']:
        assert settled not in blocking_anchors, settled
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
    # Same stale-snapshot shape as the inbox count above. BASELINE-INTEGRATION was DISPATCHABLE
    # when Cycle 1 landed and is DONE now, so asserting it is still in the plan asserts that the
    # work never happened. Its durable end state is what matters.
    #
    # SAVE-CAPTURE staying out of the plan IS durable and is the invariant worth keeping: it is
    # the broad umbrella task, and Astra was explicit that it must not dispatch with missing
    # bodies.
    states = {t['id']: t['status'] for t in q['tasks']}
    assert states.get('BASELINE-INTEGRATION') == 'done', states.get('BASELINE-INTEGRATION')
    assert 'SAVE-CAPTURE' not in planned
    # The art gates are the same kind of snapshot. Cycle 1 pinned ART-CREATURES and ART-UI-12 out
    # of the plan because neither was approved then; the pin fails the day Brendan approves
    # them, which is the gate working. The durable invariant is how an art task gets in:
    # every planned brendan_art task must name an approval that a human signed and dated.
    signed = {a['id'] for a in approvals['approvals']
              if a['status'] == 'approved' and a.get('decided_by') and a.get('decided')}
    for t in q['tasks']:
        if t['id'] in planned and t.get('gate') == 'brendan_art':
            assert t.get('approval_id') in signed, (t['id'], t.get('approval_id'))
    text=(ROOT/'docs/rulings/requests/OPEN.md').read_text()
    for i in items['items']:assert text.count(f'id="{i["anchor"]}"')==1
    packet=(ROOT/'docs/planning/review_packet.md').read_text()
    # Cycle 1 pinned the exact sentence 'Missing declarations are unknown, not approval.'
    # PR117 rewrote the packet generator with a declared grammar and said the same thing better
    # -- 'A block nobody wrote is missing evidence. It is not an approved exception'. Pinning a
    # sentence makes an improvement in wording read as a regression, so this pins the CLAIM.
    lowered = packet.lower()
    assert 'missing evidence' in lowered and 'not an approved exception' in lowered
    assert 'No nonempty declarations found' not in packet or 'does not establish' in packet
    print('PASS Cycle 1: nine-owner wire arithmetic; four malformed target refusals; twelve starter-root fixtures; archived answers; queue gates; stable inbox anchors; packet evidence limits.')
    print('Scope: planning consistency only; no production codec, physical clearance, art or save-continuation acceptance.')
    return 0

if __name__=='__main__':raise SystemExit(main())
