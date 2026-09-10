#!/usr/bin/env python3
"""Check declaration coverage and local links; this is not a game test runner."""
from pathlib import Path
from collections import Counter
import csv
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'docs/planning'
SOURCES = ['docs/game_gdd.md', 'docs/setting_rules_amendment.md',
           'docs/ui_ux_controls.md', 'docs/movement_direction_amendment.md']
DECL = re.compile(r'^\|\s*(REQ-SET-\d{3}|UI-SET-\d{3}|REQ-UX-\d{3}|MOVE-REQ-\d{3}|MOVE-TEST-\d{2}|REQ-ADM-\d{3})\b')
TASK_FILES = ['00_release_roadmap.md', '04_world_commands.md',
              '05_movement_first_playable.md', '06_buildings_rooms_logistics.md',
              '07_food_production_survival.md', '08_community_scenarios_progression.md',
              '09_persistence_replay_reliability.md', '10_presentation_qualification.md']

def main():
    errors = []
    declarations = {}
    for source in SOURCES:
        for line_no, line in enumerate((ROOT/source).read_text().splitlines(), 1):
            found = DECL.match(line)
            if found:
                declarations.setdefault(found[1], []).append((source, line_no))
    # Retirement row IDs are allocation keys, not normative declaration IDs.
    amend = 'docs/setting_rules_amendment.md'
    in_retirement = False
    retirement_no = 0
    for line_no, line in enumerate((ROOT/amend).read_text().splitlines(), 1):
        if line.startswith('## 3. '):
            in_retirement = True
        elif in_retirement and line.startswith('## '):
            break
        if in_retirement and line.startswith('| ') and not line.startswith('| Domain '):
            retirement_no += 1
            declarations[f'SET-AMEND-001-RET-{retirement_no:02}'] = [(amend, line_no)]
    rows = list(csv.DictReader((HERE/'requirements.csv').open(newline='')))
    counts = Counter(row['id'] for row in rows)
    if set(counts) != set(declarations):
        errors.append({'missing_ids': sorted(set(declarations)-set(counts)),
                       'unknown_ids': sorted(set(counts)-set(declarations))})
    if any(count != 1 for count in counts.values()):
        errors.append({'duplicate_ids': [key for key, n in counts.items() if n != 1]})
    for row in rows:
        key = row['id']
        try:
            where = (row['source'], int(row['source_line']))
            if where not in declarations.get(key, []):
                errors.append(f'{key}: declaration source/line mismatch')
        except ValueError:
            errors.append(f'{key}: invalid source_line')
        if row['evidence_status'] != 'NOT_ASSESSED':
            errors.append(f'{key}: planning matrix must not claim runtime evidence')
        if row['primary_task'] not in {f'task{n:02}' for n in range(3, 11)}:
            errors.append(f'{key}: invalid primary task {row["primary_task"]}')
    files = [ROOT/'docs/tasks'/name for name in TASK_FILES]
    files += list(HERE.glob('*.md'))
    files += [ROOT/'docs/decisions/0035-plan-through-settlement-release.md']
    links_checked = 0
    for path in files:
        if not path.exists():
            errors.append(f'missing {path.relative_to(ROOT)}')
            continue
        for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', path.read_text()):
            target = target.strip('<>').split('#', 1)[0]
            if not target or '://' in target or target.startswith('mailto:'):
                continue
            links_checked += 1
            if not (path.parent/target).resolve().exists():
                errors.append(f'{path.relative_to(ROOT)}: broken link {target}')
    report = {'scope': 'PLANNING_DECLARATIONS_AND_LOCAL_LINKS_ONLY',
              'requirements': len(rows), 'families': dict(sorted(Counter(
                  row['family'] for row in rows).items())),
              'source_declaration_count': sum(len(v) for k, v in declarations.items() if not k.startswith('SET-AMEND-001-RET-')),
              'primary_declaration_count': sum(len(v) for k, v in declarations.items() if not k.startswith(('SET-AMEND-001-RET-', 'REQ-ADM-'))),
              'retirement_dispositions': retirement_no,
              'duplicate_source_declarations': {key: val for key, val in declarations.items() if len(val)>1},
              'markdown_files': len(files), 'local_links_checked': links_checked,
              'errors': errors, 'status': 'PASS' if not errors else 'FAIL',
              'source_sha256': {source: hashlib.sha256((ROOT/source).read_bytes()).hexdigest() for source in SOURCES}}
    print(json.dumps(report, indent=2))
    return bool(errors)

if __name__ == '__main__':
    sys.exit(main())
