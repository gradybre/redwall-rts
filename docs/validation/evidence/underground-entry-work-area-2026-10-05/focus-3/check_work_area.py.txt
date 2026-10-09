#!/usr/bin/env python3
"""Frozen peer-overlay diagnostic; all original sources are restored after the strict focused run."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
BASE = Path('/Users/brendan/Developer')
SOURCES = [
    BASE/'redwall-rts-codex-ug-timber-program-binding/docs/validation/evidence/underground-timber-program-binding-2026-10-05/diagnostic-source-7',
    BASE/'redwall-rts-codex-ug-timber-program-binding/docs/validation/evidence/underground-timber-program-binding-2026-10-05/diagnostic-endpoints-2',
    BASE/'redwall-rts-codex-ug-paid-assembly-handling/docs/validation/evidence/underground-paid-assembly-handling-2026-10-05/diagnostic-declaration-6',
]
OWNED = ['godot/test/test_underground_entry_work_area.gd', 'godot/scripts/core/underground_connector_placements.gd',
         'godot/scripts/core/underground_locations.gd', 'godot/test/test_underground_entry_source_phases.gd']


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    if not out.is_relative_to(ROOT): raise ValueError('OWNED_OUTPUT_REQUIRED')
    out.mkdir(parents=True, exist_ok=False)
    overlays, manifests = {}, {}
    for source in SOURCES:
        raw = (source/'source-sha256.json').read_bytes()
        manifests[str(source)] = sha(raw)
        for name, digest in json.loads(raw).items():
            data = (source/'source'/(name+'.txt')).read_bytes()
            if sha(data) != digest: raise ValueError('SOURCE_DRIFT:'+name)
            if name in overlays and source.name != 'diagnostic-endpoints-2': raise ValueError('SOURCE_OVERLAP:'+name)
            overlays[name] = data
    originals = {name: (ROOT/name).read_bytes() if (ROOT/name).exists() else None for name in overlays}
    owned = {name: sha((ROOT/name).read_bytes()) for name in OWNED}
    record = {'manifests': manifests, 'owned': owned, 'dependency_pins': {n:sha(b) for n,b in overlays.items()},
              'scope': 'Diagnostic original work-area/source execution; no paid handling qualification'}
    for runner in [Path(__file__), Path(__file__).with_name('check_consumers.py')]:
        (out/(runner.name+'.txt')).write_bytes(runner.read_bytes())
    status = 1
    try:
        for name, raw in overlays.items():
            target=ROOT/name; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(raw)
        for name in [*overlays, *OWNED]:
            saved=out/'source'/(name+'.txt'); saved.parent.mkdir(parents=True,exist_ok=True)
            saved.write_bytes((ROOT/name).read_bytes())
        command = [sys.executable, '-B', str(Path(__file__).with_name('check_consumers.py')), '--port', '6505',
                   '--out', str(out/'focused'), '--suite', 'test_underground_entry_work_area.gd']
        for name in dict.fromkeys([*OWNED, *overlays]):
            if name.endswith('.gd'): command += ['--file', name]
        record['command'] = command
        with (out/'run.log').open('x') as log:
            status = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=1200).returncode
    finally:
        record['dependency_unchanged'] = all((ROOT/n).read_bytes()==b for n,b in overlays.items())
        for name, raw in originals.items():
            if raw is None: (ROOT/name).unlink(missing_ok=True)
            else: (ROOT/name).write_bytes(raw)
        record['original_restored'] = all(not (ROOT/n).exists() if b is None else (ROOT/n).read_bytes()==b for n,b in originals.items())
        record['owned_unchanged'] = all(sha((ROOT/n).read_bytes())==h for n,h in owned.items())
        if not all(record[k] for k in ['dependency_unchanged','original_restored','owned_unchanged']): status=1
        record['exit'] = status
        (out/'overlay.json').write_text(json.dumps(record,indent=2)+'\n')
    return status


if __name__ == '__main__':
    raise SystemExit(main())
