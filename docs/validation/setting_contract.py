"""Validate rules-v2 Markdown catalogs; this does not exercise game runtime."""
import argparse
import hashlib
import json
import re
from pathlib import Path


def tables(source):
    result = []
    block = []
    for line in source.splitlines() + ['']:
        if line.startswith('|'):
            block.append([x.strip() for x in line.strip('|').split('|')])
        elif block:
            assert len(block) >= 2, 'Missing table header'
            assert all(len(row) == len(block[0]) for row in block), block[0]
            result.append((block[0], [dict(zip(block[0], row)) for row in block[2:]]))
            block = []
    return result


def validate(docs):
    source_names = ['game_gdd.md', 'gameplay_balance.md', 'systems_architecture.md',
                    'ui_ux_controls.md', 'setting_rules_amendment.md']
    sources = {name: (docs / name).read_text() for name in source_names}
    catalog = tables(sources['gameplay_balance.md'])

    def select(required, excluded=()):
        found = [rows for header, rows in catalog
                 if set(required) <= set(header) and not set(excluded) & set(header)]
        assert len(found) == 1, required
        rows = found[0]
        assert len({r['id'] for r in rows}) == len(rows), 'Duplicate catalog key'
        return {r['id']: r for r in rows}

    items = select(['id', 'nutrition_per_u'])
    recipes = select(['id', 'inputs_milli', 'family'])
    ancillary = select(['id', 'inputs_milli'], ['family'])
    buildings = select(['id', 'footprint_x'])
    furniture = select(['id', 'floor_x'])
    crops = select(['id', 'growth_hours'])
    counts = dict(zip(['items', 'recipes', 'ancillary', 'buildings', 'furniture', 'crops'],
                      map(len, [items, recipes, ancillary, buildings, furniture, crops])))
    assert list(counts.values()) == [60, 24, 12, 30, 9, 5], counts
    retired = set('bow carcass_boar carcass_deer carcass_grouse hide hunting_tool meal_game_roast raw_game smoked_game'.split())
    assert not retired & items.keys()
    assert not {'bow', 'hunting_tool', 'smoke_game', 'game_roast'} & recipes.keys()
    assert not {'process_deer', 'process_boar', 'process_grouse'} & ancillary.keys()
    assert 'hunter_hut' not in buildings
    aquatic = sorted(key for key, row in items.items() if row['category'] == 'RAW_FISH')
    assert aquatic == 'carp dace herring mackerel mussel perch salmon trout whitefish'.split()
    dependency_count = 0
    for row in [*recipes.values(), *ancillary.values(), *buildings.values(), *furniture.values()]:
        for field in ['inputs_milli', 'outputs_milli', 'materials_milli']:
            for key, amount in re.findall(r'(@?[a-z_]+):(\d+)', row.get(field, '')):
                assert key in items or key == '@fish', (row['id'], field, key)
                assert int(amount) > 0
                dependency_count += 1
        if 'skill' in row:
            assert int(row['skill']) in [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11]
    roast = recipes['nut_roast']
    assert [roast[k] for k in ['inputs_milli', 'outputs_milli', 'work_mwu', 'passive_hours', 'station', 'skill', 'unlock']] == [
        'beans:3000;roots:2000;nuts:1000;herb:250', 'meal_nut_roast:4000', '30000', '0', 'kitchen', '6', '2']
    assert [items['meal_nut_roast'][k] for k in ['mass_g', 'nutrition_per_u', 'shelf_hours', 'raw_edible']] == ['500', '2400', '36', '1']
    inputs = []
    for level in range(11):
        quantities = [3000 * (1000 - 10 * level) // 1000, 2000 * (1000 - 10 * level) // 1000, 1000, 250]
        assert quantities[0] > max(quantities[1:])
        inputs.append(dict(cook_level=level, quantities_milli=quantities,
                           mass_g=sum((q * 250 + 999) // 1000 for q in quantities)))
    assert (inputs[0]['mass_g'], inputs[-1]['mass_g']) == (1563, 1438)
    for attendees in range(1, 257):
        portions = ((attendees + 3) // 4) * 4
        assert attendees <= portions < attendees + 4
    mastery = 'porridge root_stew fish_stew bean_hotpot nut_loaf dry_fish woodland_pie nut_roast feast_fish ration'.split()
    for key in mastery:
        assert int(recipes[key]['unlock']) <= 2
        assert not re.search(r'\b(fruit|honey):', recipes[key]['inputs_milli'])
    pool = 'mouse mole otter squirrel shrew hedgehog hare badger'.split()
    amendment = sources['setting_rules_amendment.md']
    assert ', '.join(pool) in amendment
    fixture = {}
    for day, expected in [(4, ['mole', 'otter']), (7, ['otter', 'squirrel']),
                          (10, ['squirrel', 'rat']), (13, ['shrew', 'hedgehog'])]:
        candidates = [pool[(20260905 % 8 + (day - 4) // 3 + slot) % 8] for slot in range(2)]
        if day == 10:
            candidates[-1] = 'rat'
        assert candidates == expected
        fixture[str(day)] = candidates
    assert len({pool[(20260905 % 8 + event) % 8] for event in range(8)}) == 8
    return dict(status='PASS_STATIC_SPEC_AND_REFERENCE_ONLY', catalog_counts=counts,
                resolved_dependency_edges=dependency_count, roast_levels=inputs,
                admission_reference_fixtures=fixture,
                source_sha256={name: hashlib.sha256((docs / name).read_bytes()).hexdigest() for name in source_names},
                limitations='Checks catalog definitions and independent arithmetic fixtures. Does not run admission, UI, saves, ecology, or full settlement survival in Godot.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = validate(Path(__file__).resolve().parents[1])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['status', 'catalog_counts', 'resolved_dependency_edges']}))
