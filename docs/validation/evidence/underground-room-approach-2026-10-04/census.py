#!/usr/bin/env python3
"""ADR1150 source-counted logical cold coexistence. Native allocator overhead remains unmeasured."""
import hashlib
import json
import re
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools'))
import underground_memory_budget as memory
WIDTH = {'int': 8, 'bool': 1, 'Vector2i': 8, 'Vector3i': 12}
FILE = 'godot/scripts/core/underground_room_approach.gd'
TERRAIN = 'godot/scripts/core/underground_terrain.gd'
BASE_TERRAIN = Path(__file__).resolve().parent / 'source-review-1/final-reader-repro-source/underground_terrain.gd.snapshot'


def require(value, message):
    if not value:
        raise ValueError(message)


def fields(source, name):
    found = re.findall(r'^class ' + re.escape(name) + r' extends [^:\n]+:\n((?:(?:[\t ].*|)\n)*)', source, re.M)
    require(len(found) == 1, 'exact class: ' + name)
    return memory.explicit_members(found[0], '\t')


def scalar_fields(source, name):
    return sum(WIDTH.get(kind, 0) for kind in fields(source, name).values())


def frames(source):
    """Sum every own numeric frame conservatively, even mutually exclusive and sequential paths."""
    lines, result = source.splitlines(), {}
    for start, line in enumerate(lines):
        found = re.match(r'^(\s*)(?:static )?func (\w+)\(', line)
        if not found:
            continue
        indent, name = len(found[1]), found[2]
        end = start + 1
        while end < len(lines) and (not lines[end].strip() or len(lines[end]) - len(lines[end].lstrip()) > indent):
            end += 1
        body = '\n'.join(lines[start:end]).rstrip()
        require(len(body.splitlines()) <= 30, name + ' exceeds30 physical lines')
        executable = re.sub(r'""".*?"""', '', body, flags=re.S)
        executable = re.sub(r'#.*', '', executable)
        kinds = re.findall(r'\b\w+\s*:\s*(int|bool|Vector2i|Vector3i)\b', executable)
        require(name not in result, 'duplicate function census key')
        result[name] = sum(WIDTH[kind] for kind in kinds)
    return result



def function(source, name, indent=''):
    """Extract one exact declared frame, distinguishing nested static helpers from outer wrappers."""
    lines = source.splitlines()
    matches = [i for i, line in enumerate(lines) if re.match('^' + re.escape(indent) + r'(?:static )?func ' + re.escape(name) + r'\(', line)]
    require(len(matches) == 1, 'exact helper: ' + name)
    start, end = matches[0], matches[0] + 1
    while end < len(lines) and (not lines[end].strip() or len(lines[end]) - len(lines[end].lstrip()) > len(indent)):
        end += 1
    return '\n'.join(lines[start:end]).rstrip()


def terrain_frames(terrain, owner, space):
    """All new static frames plus all transitive numeric leaf frames, even sequential branches, coexist conservatively."""
    require(memory.explicit_members(terrain) == memory.explicit_members(BASE_TERRAIN.read_text()),
            'Terrain adds no retained scalar/packed/handle field')
    names = ['prepared_local_leaf_refusal', '_final_binding_refusal', '_final_owners_match', '_final_local_tiles',
             '_final_local_tile', '_final_local_resource', '_final_local_building', '_final_building_footprint', '_final_conflict']
    selected = {name: function(terrain, name) for name in names}
    require(re.findall(r'^(?:static )?func (_final_\w+)\(', terrain, re.M) == names[1:], 'complete static final helper set')
    for name, body in selected.items():
        require(body.startswith('static func '), 'static dispatch: ' + name)
        executable = re.sub(r'""".*?"""', '', body, flags=re.S)
        executable = re.sub(r'#.*', '', executable)
        calls = re.findall(r'\b([\w.]+)\s*\(', executable)
        require(all('.' not in call or call in {'Space.valid_box', 'Space.contains_box', 'Owner.CoreSources._final_row'}
                    or call.endswith(('.get_ref', '.size', '.find')) for call in calls), 'no dynamic final observer: ' + name)
        require(not re.search(r'Packed\w+Array\s*\(|\.duplicate\s*\(|\.new\s*\(', executable), 'no final allocation: ' + name)
    additions = {name: frames(body)[name] for name, body in selected.items()}
    inherited = {
        'Terrain._natural_floor': frames(function(terrain, '_natural_floor'))['_natural_floor'],
        'Terrain._vertical_overlap': frames(function(terrain, '_vertical_overlap'))['_vertical_overlap'],
        'CoreSources._final_row': frames(function(owner, '_final_row', '\t'))['_final_row'],
        'Space.valid_box': frames(function(space, 'valid_box'))['valid_box'],
        'Space.Value.valid_box': frames(function(space, 'valid_box', '\t'))['valid_box'],
        'Space.contains_box': frames(function(space, 'contains_box'))['contains_box'],
    }
    return additions, inherited


def build(source=None, terrain=None):
    source = (ROOT / FILE).read_text() if source is None else source
    terrain = (ROOT / TERRAIN).read_text() if terrain is None else terrain
    rooms = (ROOT / 'godot/scripts/core/underground_room_bindings.gd').read_text()
    face = (ROOT / 'godot/scripts/core/underground_work_face.gd').read_text()
    profiles = (ROOT / 'godot/scripts/core/underground_profiles.gd').read_text()
    locations = (ROOT / 'godot/scripts/core/underground_locations.gd').read_text()
    owner = (ROOT / 'godot/scripts/core/underground_space_owner.gd').read_text()
    space = (ROOT / 'godot/scripts/core/room_space.gd').read_text()
    require(not memory.explicit_members(source), 'no module retained fields')
    require('const CONTROL_BYTES: int = 4096' in source, 'same own helper ceiling')
    require('const PATH_BYTES: int = Routes.MAX_EDGES * 8' in source, 'complete full-ref path output')
    require('Approach.COMPANION_BYTES' in rooms, 'whole composed admission before copies')
    require('24 * Budget.PHASE_VOLUME_CAPACITY + 384 + Face.CONTROL_BYTES + PATH_BYTES + CONTROL_BYTES' in source,
            'Locations fragments plus complete retained witness')
    require('provider._locations()._domain._regions > Budget.PHASE_VOLUME_CAPACITY' in source,
            'actual Locations admission ceiling precedes allocation')
    require('face.proof = null' in source and 'copied.cells' not in source and 'RoomPlan.new()' not in source,
            'no fourth large proof or copied footprint')
    require(source.index('face.proof = null') < source.index('func prepare_companions'), 'sequential large image lifetime')
    expected_arrays = {'extra': 'PackedInt64Array', 'boxes': 'PackedInt32Array', 'sources': 'PackedByteArray',
                       'source_read': 'PackedByteArray', 'path': 'PackedInt32Array'}
    witness_fields = fields(source, 'Witness')
    expected_refs = {'original': 'Request', 'plan': 'Orders.RoomPlan', 'binding': 'WorldRoutes',
                     'config': 'WorldRoutes.Configuration', 'face': 'Face.Check', 'travel': 'Profiles.Descriptor',
                     'work': 'Profiles.Descriptor', 'read': 'Profiles.Descriptor', 'access': 'Locations.Record',
                     'profile_bank': 'Profiles.Bank', 'graph_bank': 'Routes.EdgeBank', 'catalog_bank': 'RefCounted',
                     'context': 'Locations.RoomContext', 'candidate': 'Directory.CreateCandidate'}
    require({name: kind for name, kind in witness_fields.items() if kind not in WIDTH and not kind.startswith('Packed')} == expected_refs,
            'complete strong object/reference lifetime census')
    require({name: kind for name, kind in witness_fields.items() if kind.startswith('Packed')} == expected_arrays,
            'complete retained packed census')
    require(scalar_fields(source, 'Witness') == 32 and scalar_fields(source, 'Request') == 84, 'fixed own scalar census')
    for expression in ('extra = extra_values(request)', 'boxes.resize(2 * Profiles.MAX_SELECTION_BOXES * 7)',
                       'sources.resize(64)', 'source_read.resize(32)', 'path.resize(config.routes._edge_capacity * 2)'):
        require(expression in source, 'bounded allocation: ' + expression)
    require('PackedInt64Array([request.access.x, request.access.y, request.work_location.x, request.work_location.y,' in source,
            'fourteen exact request pins')
    descriptor = scalar_fields(profiles, 'Descriptor')
    record = scalar_fields(locations, 'Record') + 48
    domain = scalar_fields(space, 'Domain') + 24
    region = scalar_fields(owner, 'Region') + 24
    box = scalar_fields(profiles, 'Box')
    face_request = scalar_fields(face, 'Request')
    face_retained = scalar_fields(face, 'Check') + 2 * face_request + descriptor + 2 * box + 2 * record + region + domain + 96
    own_retained = scalar_fields(source, 'Witness') + scalar_fields(source, 'Request') + 3 * descriptor + record + 112 + 672 + 96 + 80
    require((descriptor, record, domain, region, box, face_request, face_retained, own_retained) ==
            (184, 116, 92, 72, 32, 68, 907, 1744), 'exact transitive packet shapes')
    levels = (ROOT / 'godot/scripts/core/underground_level_catalog.gd').read_text()
    room_fields = memory.explicit_members(rooms)
    room_fixed = sum(WIDTH.get(kind, 0) for kind in room_fields.values()) + 48 + region + scalar_fields(levels, 'Record')
    require(room_fixed == 227 and set(name for name, kind in room_fields.items() if kind.startswith('Packed')) == {'_cube', '_clip'},
            'actual retained RoomBindings census')
    own_frames = frames(source)
    added_frames, inherited_frames = terrain_frames(terrain, owner, space)
    terrain_helpers = sum(added_frames.values()) + sum(inherited_frames.values())
    own_helpers = own_retained + sum(own_frames.values()) + terrain_helpers + 512 + 512
    require(own_helpers <= 4096, 'witness plus all own/static Terrain/transitive frames, profile path512 and expression512')
    require('const CONTROL_BYTES: int = 2048' in face and face_retained <= 2048, 'separately retained inherited Face allowance')
    n, snapshot, path, helper, face_helper, room_helper = 16384, 48 * 6144 + 16 * 2048, 1536 * 8, 4096, 2048, 2048
    retained = path + helper + face_helper
    phases = {
        'initial_room_survey': snapshot + 8*n + 24*n + room_helper,
        'pre_candidate_work_face': snapshot + 48*1024 + face_helper + path + helper + 24*n + room_helper,
        'locations_preparation': snapshot + 24*8192 + 384 + retained + 24*n + room_helper,
        'world_routes_preparation': snapshot + 48*1024 + 1024 + retained + 24*n + room_helper,
        'after_sites_and_final_publication': 40*n + room_helper + retained,
    }
    require(max(phases.values()) == 938368 and max(phases.values()) <= 1048960, 'complete composed peak')
    return dict(schema=3, source_sha256=hashlib.sha256(source.encode()).hexdigest(),
                terrain_sha256=hashlib.sha256(terrain.encode()).hexdigest(),
                persistent_room_bindings_numeric=227, persistent_limit=512,
                added_handles=['weak actual WorldRoutes', 'lease-bound Witness'],
                module_retained_numeric=0, module_retained_packed=0, max_cells=n,
                full_shared_cold_bytes=1048960, original_plan_images=3, after_sites_plan_images=4,
                snapshot_bytes=snapshot, original_path_bytes=path,
                new_witness_and_request_fixed=own_retained, retained_face_fixed=face_retained,
                own_numeric_frames=own_frames, own_conservative_frame_sum=sum(own_frames.values()),
                terrain_added_numeric_frames=added_frames, terrain_inherited_numeric_frames=inherited_frames,
                terrain_helper_counted=terrain_helpers, terrain_added_retained=0,
                own_helper_counted=own_helpers, own_helper_allowance=helper,
                inherited_face_allowance=face_helper, existing_room_sites_allowance=room_helper,
                reviewed_foreign_final_tail_counted=1984, peaks=phases, maximum_peak=max(phases.values()),
                logical_headroom=1048960-max(phases.values()), runtime_qualified=False, native_measured=False,
                lifetime='All cold strong owners, request/source packets and path survive through final publication. '
                         'Face image/fragments die before Locations; Locations image/fragments die before WorldRoutes; '
                         'WorldRoutes image/fragments die before Sites. Existing Room/Sites2048 counts once. '
                         'Reference/control/allocator overhead remains unmeasured, not zero.')


if __name__ == '__main__':
    print(json.dumps(build(), indent=2))
