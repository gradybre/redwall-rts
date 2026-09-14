#!/usr/bin/env python3
"""Independent Cycle 2 contract fixtures, not production save/physics acceptance."""
from pathlib import Path
import copy, hashlib, importlib.util, json, struct
ROOT=Path(__file__).resolve().parents[2]
CHECKS=0
def check(value):
    global CHECKS
    CHECKS+=1
    assert value
def partition(live,gen,prefix):
    if len(live)!=len(gen) or len(prefix)>len(live):raise ValueError('extent')
    if any(x not in (0,1) for x in live) or any(not 1<=g<=2147483647 for g in gen):raise ValueError('identity')
    if len(set(prefix))!=len(prefix) or any(not 0<=s<len(live) or live[s] for s in prefix):raise ValueError('prefix')
    if any(not live[s] and s not in prefix and gen[s]!=2147483647 for s in range(len(live))):raise ValueError('lost slot')
def projection(data,target):
    result=copy.deepcopy(data)
    for family in ['c','l']:
        rows=data[family];prefix=data[family+'_free'][:data[family+'_count']]
        partition([r['live'] for r in rows],[r['generation'] for r in rows],prefix)
        result[family+'_free']=prefix
        for row in result[family]:
            if row['live']==0:row.update(target['inactive_values'][family])
    return result
def bytes_of(data):
    # Deterministic reference representation only, not RWL-STATE-1 wire bytes.
    return json.dumps(data,sort_keys=True,separators=(',',':')).encode()
def fit(lo,hi,offset):
    a=[lo[i]+offset[i] for i in range(2)];b=[hi[i]+offset[i] for i in range(2)]
    if any(a[i]<0 or b[i]<a[i] for i in range(2)):raise ValueError('placement')
    k=max(1,*[(x+511)//512 for x in b])
    if k>512:raise ValueError('class')
    return k
def refuse(fn):
    try:fn()
    except ValueError:check(True)
    else:check(False)
def main():
    target=json.loads((ROOT/'docs/planning/astra_cycles/cycle_02_inventory_target.json').read_text())
    check(target['active_registry_mutated'] is False)
    registry=json.loads((ROOT/'docs/planning/canonical_state_registry.json').read_text())
    owner=next(o for o in registry['owners'] if o['owner_key']=='inventory')
    check([(f['field_key'],f['ordinal'],f['type']) for f in owner['fields']]==[(f['field_key'],f['ordinal'],f['type']) for f in target['fields']])
    c=dict(target['inactive_values']['c'],live=0,generation=1)
    l=dict(target['inactive_values']['l'],live=0,generation=2)
    d={'c':[dict(c,live=1),c], 'l':[dict(l,live=1,_l_quantity_milli=2000,_l_reserved_milli=250),l],
       'c_free':[1,777], 'l_free':[1,888], 'c_count':1,'l_count':1}
    dead=d['l'][1];dead.update(_l_reserved_milli=250,_l_item_id=7,_l_provenance=3)
    original=copy.deepcopy(d);p=projection(d,target)
    check(d==original);check(p['l'][1]['_l_reserved_milli']==0);check(p['l'][0]['_l_reserved_milli']==250)
    check(p['c_free']==[1] and p['l_free']==[1])
    e=copy.deepcopy(d);e['l'][1].update(_l_provenance=5,_l_recipe_id=222);e['l_free'][1]=-555
    check(bytes_of(projection(e,target))==bytes_of(p))
    e=copy.deepcopy(d);e['l'][1]['generation']=3
    check(bytes_of(projection(e,target))!=bytes_of(p))
    e=copy.deepcopy(d);e['l'][0]['_l_quantity_milli']=2001
    check(bytes_of(projection(e,target))!=bytes_of(p))
    e=copy.deepcopy(d);e['l'][0].update(_l_container_slot=-1,_l_container_generation=0,_l_provenance=3)
    check(projection(e,target)['l'][0]['_l_provenance']==3)
    a=copy.deepcopy(d);a['l'][0]['live']=0;a['l_count']=2;a['l_free']=[0,1]
    b=copy.deepcopy(a);b['l_free']=[1,0]
    check(bytes_of(projection(a,target))!=bytes_of(projection(b,target)))
    for live,gen,prefix in [([0],[2147483647],[0]),([0],[2147483647],[]),([1],[2147483647],[])]:
        partition(live,gen,prefix);check(True)
    for args in [([0],[0],[0]),([0],[1],[]),([1],[1],[0]),([0],[1],[0,0]),([2],[1],[])]:refuse(lambda args=args:partition(*args))
    # Strict wire mask validator: a dead-row source projection is not a loader repair.
    def validate_wire(row,defaults):
        if not row['live'] and any(row[k]!=v for k,v in defaults.items()):raise ValueError('noncanonical wire')
    bad=copy.deepcopy(p['l'][1]);bad['_l_provenance']=6
    refuse(lambda:validate_wire(bad,target['inactive_values']['l']))
    check(fit((-256,-256),(256,256),(256,256))==1)
    check(fit((-256,-256),(257,256),(256,256))==2)
    refuse(lambda:fit((-257,-100),(255,100),(256,256)))
    check(fit((0,0),(262144,262144),(0,0))==512)
    refuse(lambda:fit((0,0),(262145,1),(0,0)))
    # Signed outward quantization oracle on exact rational imports; synthetic only.
    def quantize(n,d,margin):
        return (n*1024//d-margin,-((-n*1024)//d)+margin)
    check(quantize(-1,1000,0)==(-2,-1));check(quantize(1,1000,1)==(0,3))
    q=json.loads((ROOT/'docs/planning/work_queue.json').read_text());tasks={t['id']:t for t in q['tasks']}
    items=json.loads((ROOT/'docs/rulings/requests/open_items.json').read_text());answered={i['anchor']:i for i in items['answered']}
    check(tasks['BASELINE-INTEGRATION']['status']=='done')
    for tid,key in [('DIGEST-DETERMINISM','retired-row-blanking'),('CONSTRUCTION-GOODS','inventory-container-enumeration-by-owner')]:
        check(tasks[tid]['astra_answered'] is True and key in answered)
        path,anchor=answered[key]['ruling'].split('#');check(f'id="{anchor}"' in (ROOT/path).read_text())
    check(tasks['MOVE-ENVELOPES'].get('astra_answered') is not True)
    check([i['anchor'] for i in items['items'] if i['blocks']]==['move-g01-clearance-and-modes'])
    # These two pin Astra's PR-QUERY SNAPSHOT, not a contract. PR117 merged after
    # that snapshot was taken, so 'review' became 'done' and the original pin would
    # now fail on a tree that is more correct than the one it was written against.
    # The PR NUMBER is the durable half and stays exact; the status is allowed to
    # advance, because a lane may only move forward from review. Same distinction as
    # packed_source_field_count: a snapshot that REG-R01 requires to grow is not a
    # format constant, and freezing one refuses every later landing.
    check(tasks['PACKET-EVIDENCE']['status'] in ('review','done') and tasks['PACKET-EVIDENCE']['pr']==117)
    check(tasks['ART-UI-12-EVIDENCE']['status'] in ('review','done') and tasks['ART-UI-12-EVIDENCE']['pr']==118)
    check(not any(a['status']=='approved' for a in json.loads((ROOT/'docs/planning/art_approvals.json').read_text())['approvals']))
    print(f'PASS Cycle 2 contract fixtures: {CHECKS} checks; projection, allocator, fit, gate and handoff cases.')
    print('No production codec, body measurement, movement admission, visual approval or save-continuation result is inferred.')
if __name__=='__main__':main()
