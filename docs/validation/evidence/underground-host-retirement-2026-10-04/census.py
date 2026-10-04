#!/usr/bin/env python3
"""Exact new Session/host fields and composed retirement frames; native widths remain provisional."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
OLD = ROOT / 'docs/validation/evidence/underground-world-retirement-2026-10-04/census.py'
SPEC = importlib.util.spec_from_file_location('accepted_1155_census', OLD)
K = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(K)
FILES = dict(K.FILES, Host='godot/scripts/systems/settlement_system.gd')
WIDTH = dict(K.WIDTH, void=0, float=8)
ROOTS = ['Host.reset', 'Host.prepare_world_reset', 'Host.abandon_world_reset', 'Host._notification',
         'Host.underground_session', 'Host.underground_content', 'Host._retirement_project_refusal',
         'Session._build_retirement_owners']
BOOL_GUARDS = ['create_generated_settlement', 'create_initial_settlement', 'materialize_starter_colony',
               'create_placed_cohort_on', 'mount_underground', 'run_tick', 'run_day_boundary']
NAME_GUARDS = ['cancel_demolition', 'release_stranded_reservation', 'cancel_furniture_removal', 'cancel_evacuation']
REPORT_GUARDS = ['preview_demolition', 'complete_demolition', 'preview_furniture_removal', 'complete_furniture_removal']
# These unchanged callees retain their original owner reservations. The composed prefix at their
# invocation is counted below; no second Catalog/source image or complete clear-store arena is claimed.
BOUNDARIES = {'Session._content_refusal': ['Catalog.runtime_sources_refusal', 'Catalog.content_refusal'],
              'Session._observe_current': ['Levels.binding_matches', 'Terrain.binding_refusal'],
              'Host._clear_stores': ['existing concrete store clear/reset methods'],
              'Host._clear_stock_layer': ['Inventory.clear', 'Items.load_default', 'StockAge.clear'],
              'Host._release_critical_pause': ['existing SimClock critical-pause release']}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def prior(root):
    rows = json.loads((HERE / 'predecessor/manifest.json').read_text())
    result = {}
    for name in ('Session', 'Host'):
        row = rows[FILES[name]]
        data = (root / row['locator']).read_bytes()
        require(digest(data) == row['sha256'], 'predecessor drift: ' + name)
        result[name] = data.decode()
    require(digest(OLD.read_bytes()) == rows[str(OLD.relative_to(ROOT))]['sha256'], 'accepted census source drift')
    return result


def members(source):
    rows = re.findall(r'^var (\w+): ([\w.]+)', source, re.M)
    require(len(rows) == len(re.findall(r'^var ', source, re.M)), 'untyped member')
    return dict(rows)


def parse(source, module):
    result = {}
    pattern = r'^(static )?func (\w+)\((.*?)\) -> ([\w.]+):\n(.*?)(?=^(?:static )?func |\Z)'
    for match in re.finditer(pattern, source, re.M | re.S):
        static, name, params, returns, body = match.groups()
        params_ = re.findall(r'(\w+):\s*([\w.]+)', params)
        locals_ = re.findall(r'^\s*(?:@[^\n]* )?var (\w+):\s*([\w.]+)', body, re.M)
        values = params_ + locals_
        require(len(params_) == params.count(':'), 'untyped argument ' + name)
        require(len(locals_) == len(re.findall(r'^\s*(?:@[^\n]* )?var ', body, re.M)), 'untyped local ' + name)
        executable = re.sub(r'""".*?"""', '', body, flags=re.S)
        executable = re.sub(r'#[^\n]*', '', executable)
        calls = [module + '.' + x for x in re.findall(r'(?<![.\w])([_a-zA-Z]\w*)\(', executable)]
        calls += ['Retirement.' + x for x in re.findall(r'\bRetirement\.([a-z_]\w*)\(', executable)]
        if module == 'Host':
            calls += ['Session.' + x for x in re.findall(r'\b(?:original|_underground_session)\.([a-z_]\w*)\(', executable)]
        numeric = sum(WIDTH.get(kind, 0) for _, kind in values) + WIDTH.get(returns, 0)
        refs = sum(kind not in WIDTH for _, kind in values) + int(static is None) + int(returns not in WIDTH)
        result[module + '.' + name] = {'numeric_and_name_bytes': numeric, 'reference_values': refs,
            'calls': sorted(set(calls)), 'returns': returns, 'body': body, 'values': values,
            'implicit_self_counted': static is None}
    return result


def closure(frames):
    selected = set()
    def visit(name):
        if name in selected:
            return
        require(name in frames, 'missing root ' + name)
        selected.add(name)
        for child in frames[name]['calls']:
            if child in frames:
                visit(child)
    for root in ROOTS:
        visit(root)
    return {name: dict(frames[name], calls=[x for x in frames[name]['calls'] if x in selected]) for name in sorted(selected)}


def guarded(body):
    code = re.sub(r'""".*?"""', '', body, flags=re.S).lstrip()
    return code.startswith('if _underground_reset_phase != 0:')


def build(root=ROOT, replacements=None):
    old = prior(root)
    sources = {name: (root / path).read_text() for name, path in FILES.items()}
    sources.update(replacements or {})
    inherited = {name: text for name, text in (replacements or {}).items() if name in K.FILES}
    inherited['Session'] = old['Session']
    base = K.build(root, inherited)
    before, after = members(old['Session']), members(sources['Session'])
    require({k: v for k, v in after.items() if k not in before} ==
            {'_retirement_owners': 'Retirement.Owners', '_retirement_scope': 'Retirement.Scope'}, 'exact two Session references')
    require(all(after.get(k) == v for k, v in before.items()), 'existing Session fields unchanged')
    host_before, host_after = members(old['Host']), members(sources['Host'])
    require({k: v for k, v in host_after.items() if k not in host_before} == {'_underground_reset_phase': 'int'}, 'exact host phase')
    require(all(host_after.get(k) == v for k, v in host_before.items()), 'existing host fields unchanged')
    require(re.findall(r'^const \w+: (?:int|bool|Vector\di).*$', sources['Session'], re.M) ==
            re.findall(r'^const \w+: (?:int|bool|Vector\di).*$', old['Session'], re.M), 'no Session constant/reserve growth')
    require(re.findall(r'^const \w+: (?:int|bool|Vector\di).*$', sources['Host'], re.M) ==
            re.findall(r'^const \w+: (?:int|bool|Vector\di).*$', old['Host'], re.M), 'no host numeric constants added')
    frames = {name: dict(row) for name, row in base['static_frames'].items()}
    own = dict(parse(sources['Session'], 'Session'), **parse(sources['Host'], 'Host'))
    frames.update(own)
    for name in BOOL_GUARDS + NAME_GUARDS + REPORT_GUARDS:
        require(guarded(own['Host.' + name]['body']), 'fresh host operation not stopped: ' + name)
    prepare = own['Host.prepare_world_reset']['body']
    require(prepare.index('_underground_reset_phase = 1') < prepare.index('retirement_observation_refusal'), 'stop before observation')
    require(prepare.index('code = _mounted_underground_refusal(original)', prepare.index('retirement_observation_refusal')) <
            prepare.index('original.prepare_retirement'), 'exact post-observation host proof')
    require('if _underground_reset_phase == 1 or _underground_reset_phase == 3:' in prepare, 'no recursive prepare/clear')
    reset = own['Host.reset']['body']
    require(reset.index('_underground_reset_phase = 3') < reset.index('_clear_stores()') <
            reset.index('_release_underground_after_clear()') < reset.index('_underground_reset_phase = 0'), 'clear/release/stop order')
    require('if _underground_reset_phase != 2 or _underground_session == null:' in own['Host.abandon_world_reset']['body'], 'no abandon after clear')
    for name in ('release_retirement', '_drop_foundations', '_discard_retirement_on_host_free'):
        require('_retirement_scope = null' in own['Session.' + name]['body'], 'strong cycle drop: ' + name)
    drop = own['Session._drop_foundations']['body']
    require(drop.index('_retirement_scope = null') < drop.index('_retirement_owners = null'), 'Scope dies before Owners')
    require('if _retirement_scope != null:' in own['Session._current_refusal']['body'], 'pending scope blocks current getters')
    require(sources['Session'].count('Retirement.Owners.new()') == 1 and
            sources['Session'].count('Retirement.Scope.new()') == 1, 'only permanent packet and temporary Scope allocated')
    allocation = own['Session.prepare_retirement']['body']
    require('if _retirement_scope == null:\n\t\t_retirement_scope = Retirement.Scope.new()' in allocation, 'repeated prepare shares original Scope')
    selected = closure(frames)
    for name, row in selected.items():
        if name in own:
            require(all(kind not in ('Variant', 'Array', 'Dictionary') and not kind.startswith('Packed') for _, kind in row['values']),
                    'variable new helper shape: ' + name)
            require(not re.search(r'\bfor ', re.sub(r'""".*?"""', '', row['body'], flags=re.S)), 'count loop variable explicitly: ' + name)
        row.pop('body', None)
        row.pop('values', None)
    numeric, chain = K.longest(selected, 'numeric_and_name_bytes')
    refs, ref_chain = K.longest(selected, 'reference_values')
    controls = base['proposal']['control_arithmetic']['total_provisional'] + 2 * 32 + 8
    helpers = numeric + refs * 32 + 256
    require(controls <= 6144 and helpers <= 2048, 'existing retirement slice exceeded')
    return {'scope': 'Actual host/Session source composition; no measured native or operational Room mount claim',
        'source_sha256': {FILES[name]: digest(text.encode()) for name, text in sources.items()},
        'original_session_numeric_bytes': 27, 'original_session_reference_slots': 24, 'original_session_reserved_bytes': 1536,
        'session_added_reference_slots': 2, 'host_added_numeric_bytes': 8, 'packed_bank_delta': 0,
        'simultaneous_scope_owners_reference_slots': base['additional_simultaneous_caller_and_scope']['reference_slots'],
        'joint_numeric_bytes': base['joint_member_numeric_bytes'] + 8,
        'joint_reference_slots': base['joint_member_reference_slots'] + 2,
        'frames': selected, 'maximum_numeric_bytes': numeric, 'maximum_numeric_chain': chain,
        'maximum_reference_values': refs, 'maximum_reference_chain': ref_chain,
        'existing_owner_boundaries': BOUNDARIES,
        'accounting': {'retirement_reserved_bytes': 8192, 'control_slice': 6144, 'helper_slice': 2048,
            'control_provisional_bytes': controls, 'control_remaining': 6144-controls,
            'helper_provisional_bytes': helpers, 'helper_remaining': 2048-helpers,
            'reference_bytes_assumed': 32, 'existing_three_objects_bytes_assumed': 768,
            'existing_native_symbol_bytes_assumed': 2048, 'helper_expression_bytes_assumed': 256,
            'profile_ceiling': 262144, 'parent_1156_joint_bytes': 238676, 'joint_with_retirement': 246868},
        'lifetime': 'One permanent Session-owned caller Owners plus one private Scope and its fixed Owners copy; '
                    'the original Session1536 is charged once, and the two new references/host integer are in retirement8192. '
                    'All own selected call frames include implicit self and reference-valued returns; complete accepted1155 '
                    'static owner frames are composed. Original cold source checking and store-clear internals keep their '
                    'existing owner reservations, with each caller prefix included here. No new source image is decoded/copied.',
        'native_measured': False, 'runtime_qualified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    data = json.dumps(build(), indent=2) + '\n'
    if args.out:
        require(not args.out.exists() and not args.out.is_symlink(), 'create-only output')
        args.out.write_text(data)
    else:
        print(data, end='')
