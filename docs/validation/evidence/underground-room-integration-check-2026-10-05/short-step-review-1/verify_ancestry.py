#!/usr/bin/env python3
"""Verify immutable input ancestry without ever replacing a live source file."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path('/Users/brendan/Developer/redwall-rts-codex-ug-short-work-step-runtime')
OUT = Path(__file__).resolve().parent
OLD = ROOT / 'godot/data/underground/mole-worker/profile-publication-v3/manifest.json'
REPORT = ROOT / 'docs/validation/evidence/underground-short-work-step-2026-10-05/source-3/result/step-program.json'
RAW_ASSETS = Path('/Users/brendan/Developer/redwall-rts-codex-ug-work-approach')

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def main():
    assert sha(OLD.read_bytes()) == '8f210e11768131779e6c825d7a3d2509cb32076aedd6891e6573489d1b6814c1'
    assert sha(REPORT.read_bytes()) == 'fff35c8c2ead2f43a68a242ca3ac156f9348af1880a00dd7ebbb16aaa1f476a0'
    old, report = json.loads(OLD.read_text()), json.loads(REPORT.read_text())
    groups = {'old_v3_prerequisites': old['prerequisite_pins'],
              'source1164_direct_inputs': report['source_inputs'],
              'source1164_producers': report['producer_sources']}
    verified, failed = {}, []
    for label, pins in groups.items():
        group = {}
        for name, expected in pins.items():
            path = ROOT / name
            if path.is_file() and sha(path.read_bytes()) == expected:
                group[name] = {'sha256': expected, 'kind': 'current_immutable_file', 'locator': name}
                continue
            # Only the exact original published commit is permitted for changed
            # old source. Its bytes are read through Git; nothing is overlaid.
            if label == 'old_v3_prerequisites' and name.endswith('.gd'):
                locator = old['consumer_commit'] + ':' + name
                result = subprocess.run(['git', 'show', locator], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                if result.returncode == 0 and sha(result.stdout) == expected:
                    group[name] = {'sha256': expected, 'kind': 'historical_git_object', 'locator': locator}
                    continue
            if name.startswith('godot/demo/assets/'):
                raw = RAW_ASSETS / name
                if raw.is_file() and sha(raw.read_bytes()) == expected:
                    group[name] = {'sha256': expected, 'kind': 'unchanged_raw_asset', 'locator': str(raw)}
                    continue
            failed.append({'group': label, 'path': name, 'expected': expected})
        verified[label] = group
    output = {'groups': verified, 'counts': {k:len(v) for k,v in verified.items()},
              'failed': failed, 'historical_live_substitutions': 0,
              'source1164_report_sha256': sha(REPORT.read_bytes()), 'old_v3_manifest_sha256': sha(OLD.read_bytes())}
    (OUT / 'source-ancestry.json').write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps({'counts': output['counts'], 'failed': failed, 'historical_live_substitutions': 0}, indent=2))
    assert not failed

if __name__ == '__main__':
    main()
