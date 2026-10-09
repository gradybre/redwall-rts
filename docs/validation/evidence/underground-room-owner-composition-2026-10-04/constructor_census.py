#!/usr/bin/env python3
"""Exact existing constructor scratch, separate from already reserved owner banks.

Native headers/Variant references remain provisional (256/32 bytes), not allocator
measurements. The fixed manifest binds the reviewed unchanged constructor bodies;
this module never imports or executes an unverified historical producer.
"""
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MANIFEST_SHA = '4dfe119a902a11e99226fc6100e9c8bb596349efdef875af409e9b239731ff50'
WIDTH = {'int':8, 'float':8, 'bool':1, 'Vector2i':8, 'Vector3i':12, 'StringName':8, 'void':0}
ALIASES = {'Provider':'underground_world_bindings', 'Authority':'underground_space_authority',
 'Owner':'underground_space_owner', 'Domain':'room_space', 'Value':'room_space', 'Sites':'excavation_sites',
 'Funding':'excavation_inventory', 'Router':'modular_projects', 'Orders':'underground_room_orders',
 'Locations':'underground_locations', 'Inventory':'inventory', 'Construction':'construction',
 'Work':'work', 'Reservations':'reservations', 'Directory':'entity_directory'}


def require(value, message):
    if not value: raise ValueError(message)


def verify(replacements=None):
    data=(HERE/'constructor-source-sha256.json').read_bytes()
    require(hashlib.sha256(data).hexdigest()==MANIFEST_SHA, 'constructor manifest drift')
    result={}
    for path,row in json.loads(data).items():
        value=(replacements or {}).get(path, (ROOT/path).read_text())
        require(hashlib.sha256(value.encode()).hexdigest()==row['sha256'], 'constructor source drift '+path)
        result[path]=value
    return result


def scoped(source, name):
    if not name: return source
    match=re.search(r'^class '+re.escape(name)+r'\b[^\n]*:\n(.*?)(?=^\S|\Z)',source,re.M|re.S)
    require(match is not None, 'missing constructor class '+name)
    return '\n'.join(line[1:] if line.startswith('\t') else line for line in match[1].splitlines())+'\n'


def frame(source, name, nested=None):
    source=scoped(source,nested)
    match=re.search(r'^(static )?func '+re.escape(name)+r'\((.*?)\) -> ([\w.]+):\n(.*?)(?=^(?:static )?func |\Z)', source,re.M|re.S)
    require(match is not None, 'missing constructor frame '+name)
    static,params,returns,body=match.groups()
    arguments=re.findall(r'(\w+):\s*([\w.]+)',params)
    local=re.findall(r'^\s*(?:@[^\n]* )?var (\w+):\s*([\w.]+)',body,re.M)
    loops=re.findall(r'\bfor (\w+): ([\w.]+) in ',body)
    require(len(arguments)==params.count(':'), 'untyped constructor arguments')
    require(len(local)==len(re.findall(r'^\s*(?:@[^\n]* )?var ',body,re.M)), 'untyped constructor locals')
    # Each syntactic loop declaration is charged, even sequential loops of the same name.
    values=arguments+local+loops
    numeric=sum(WIDTH.get(t,0) for _,t in values)+WIDTH.get(returns,0)
    references=sum(t not in WIDTH for _,t in values)+int(static is None)+int(returns not in WIDTH)
    return {'numeric_and_name_bytes':numeric, 'reference_values':references,
            'provisional_frame_bytes':numeric+references*32,
            'body_sha256':hashlib.sha256(match[0].encode()).hexdigest(), 'values':values}


def build(own, source_replacements=None):
    sources=verify(source_replacements)
    def get(label):
        module,method=label.split('.',1)
        nested=None
        if module in ('Domain','Value'): nested=module
        if module=='LocationBank': module='Locations';nested='Bank'
        if module=='InventoryLocations':module='Locations';nested='InventoryLocations'
        if module.endswith('Result'): module=module[:-6];nested='OpResult'
        if module in own: return frame(own[module],method,nested)
        return frame(sources['godot/scripts/core/'+ALIASES[module]+'.gd'],method,nested)
    roots=['Host.compose_underground_room_owners','Session.compose_room_owners','Composition.construct']
    domain_tail=['Owner.domain_copy','Owner._copy_domain','Domain.configure','Value.int32']
    cases={}
    def case(name,own_leaf,tail,heap=0,note=''):
        labels=roots+[own_leaf]+tail
        rows={key:get(key) for key in labels}
        declared=sum(row['provisional_frame_bytes'] for row in rows.values())
        cases[name]={'chain':labels,'frames':rows,'declared_provisional_bytes':declared,
          'transient_heap_bytes':heap,'expression_bytes':256,'total':declared+heap+256,'note':note}
    # One 8-entry descriptor (key+value each a Variant), its copied bounds,
    # configure's six-int temporary, a six-Variant constructor list, and the
    # new Domain including its retained bounds/header. The latter is charged
    # again here conservatively even when the receiving owner retains it.
    domain_heap={'descriptor_entries':8*2*32, 'dictionary_header':256,
      'descriptor_bounds_copy':24+256, 'configure_bounds_temporary':24+256,
      'six_value_constructor_array':6*32+256, 'domain_fields_and_bounds':92,
      'domain_header':256, 'domain_bounds_header':256}
    for name,leaf,callee in [
      ('provider_domain','Composition._prepare_phase','Provider.configure'),
      ('authority_domain','Composition._prepare_phase','Authority.configure'),
      ('room_domain','Composition._bind_rooms','Orders.configure'),
      ('location_domain','Composition._bind_locations','Locations.configure')]:
        case(name,leaf,[callee]+domain_tail,sum(domain_heap.values()),
          'Exact descriptor -> new Domain; no Scope/private Owners copy exists during construct.')
    # Sites' four-field economic Domain is a distinct, temporary 44-byte object.
    case('site_domain','Composition._bind_excavation',
      ['Sites._init','Sites._initialization_refusal','Sites._read_domain','Authority.domain_into'],44+256)
    # Packed-array loop values alias each owner's already admitted arena. The
    # Array list/header and every declared loop alias are still counted here.
    case('site_allocation','Composition._bind_excavation',['Sites._init','Sites._allocate_columns'],10*32+256)
    for name,count in [('_allocate_projects',5),('_allocate_receipts',6),('_allocate_scratch',4)]:
        case('funding'+name,'Composition._bind_excavation',['Sites._init','Funding._init','Funding.'+name],count*32+256)
    # Three result objects can coexist at the last Sites binding (25+25+17
    # numeric/name bytes); headers remain an explicit provisional assumption.
    case('site_publish','Composition._bind_excavation',
      ['Sites._init','Sites._publish_owner_bindings','Work.bind_excavation_authority','Work._succeed','WorkResult._init'],
      67+3*256)
    case('router_allocation_and_results','Composition._bind_router',['Router._init'],4*32+256+42+2*256,
      'Conservatively includes the sequential alias list plus both binding results.')
    case('router_final_result','Composition._bind_router',
      ['Router._init','Work.bind_modular_authority','Work._succeed','WorkResult._init'],42+2*256)
    case('borrowed_catalog','Composition._bind_rooms',['RoomCatalog._init'],32+256,
      'One retained adapter reference/header, conservatively repeated here; no BuildingDefinitions constructor.')
    case('location_bank','Composition._bind_locations',['Locations.configure','LocationBank.allocate'],2*32+256)
    case('inventory_arena','Composition._bind_locations',
      ['Composition._bind_inventory','Inventory.bind_spatial_locations','Inventory._allocate_spatial_arena'],25+256)
    case('inventory_adapter','Composition._bind_locations',
      ['Composition._bind_inventory','Inventory.bind_spatial_locations','InventoryLocations.exact_binding',
       'Locations.exact_inventory_binding','Locations.world_ref','Directory.is_valid'],25+256)
    # Constructor return/identity observers are existing owner methods with
    # their own source-counted reservations. Keep the complete new caller
    # prefix here; no new snapshot/proof or fresh cold lease is opened.
    maximum=max(cases,key=lambda key:cases[key]['total'])
    return {'source_manifest_sha256':MANIFEST_SHA,'domain_heap':domain_heap,
      'cases':cases,'maximum_case':maximum,'maximum_provisional_bytes':cases[maximum]['total'],
      'additional_retained_packed_bytes':0,
      'existing_reservations':{
       'WorldBindings and inherited Entry/Room controls':'existing binding/provider reservation, one actual provider',
       'Authority proof columns':'69*256+60 within existing PROOF_BYTES; one cache',
       'Sites history':'MAX_SITE_CAPACITY=73909 within existing 8388608, one history',
       'Funding':'MAX_RECEIPT_CAPACITY=32768; one Sites Funding also borrowed by Router',
       'Router job mapping':'one already counted JOB_CAPACITY=8192 arena',
       'Room bindings/Orders':'existing controls/empty fixed RoomPlan; no cell/proof arrays allocated',
       'Locations':'two 1024-row banks within existing 233728; no endpoint/cold snapshot',
       'Inventory endpoints':'existing five 1024-I32 arrays, identical arena reused after retirement',
       'RoomCatalog':'one reference to the original Buildings definitions; no duplicate 1752-byte catalog',
       'source checking':'existing bounded Catalog source-hash workspace; no new image decode'},
      'native_measured':False,'runtime_qualified':False}
