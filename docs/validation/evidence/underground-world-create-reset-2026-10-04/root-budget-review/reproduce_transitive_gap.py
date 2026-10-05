#!/usr/bin/env python3
"""Replay the retirement provenance gap in an isolated copied source tree only."""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import types

HERE = Path(__file__).resolve().parent
PRODUCER = 'docs/validation/evidence/underground-world-retirement-2026-10-04/census.py'
OUTER = 'docs/validation/evidence/underground-host-retirement-2026-10-04/census.py'
MANIFEST = 'docs/validation/evidence/underground-host-retirement-2026-10-04/predecessor/manifest.json'
WRAPPER = 'tools/underground_retirement_memory.py'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def load_wrapper(raw, root):
    module = types.ModuleType('reviewed_retirement_wrapper')
    module.__file__ = str(root / WRAPPER)
    exec(compile(raw, module.__file__, 'exec', optimize=0), module.__dict__)
    return module


def run(wrapper=None, expect_refusal=False):
    rows = json.loads((HERE / 'reproducer-inputs.json').read_text())
    originals = {}
    for path, row in rows.items():
        raw = (HERE / row['locator']).read_bytes()
        if digest(raw) != row['sha256']:
            raise ValueError('review input drift: ' + path)
        originals[path] = raw
    raw_wrapper = wrapper.read_bytes() if wrapper else originals[WRAPPER]
    with tempfile.TemporaryDirectory(prefix='ug-retirement-review-') as temporary:
        root = Path(temporary)
        for path, raw in originals.items():
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        index = {Path(path).stem: types.SimpleNamespace(text=raw.decode())
                 for path, raw in originals.items() if path.endswith('.gd')}
        session = {'profile_level_motion_session_joint_bytes': 238676}
        before = load_wrapper(raw_wrapper, root).build(index, session, 262144)
        producer = (root / PRODUCER).read_text()
        original_term = "'total_provisional': provisional_control"
        if producer.count(original_term) != 1:
            raise ValueError('exact mutant target changed')
        (root / PRODUCER).write_text(producer.replace(original_term, "'total_provisional': 0", 1))
        manifest = json.loads((root / MANIFEST).read_text())
        manifest[PRODUCER]['sha256'] = digest((root / PRODUCER).read_bytes())
        (root / MANIFEST).write_text(json.dumps(manifest, indent=2) + '\n')
        try:
            after = load_wrapper(raw_wrapper, root).build(index, session, 262144)
            accepted, error = True, None
            changed = after['accounting']['control_provisional_bytes']
        except (AssertionError, ValueError) as refusal:
            accepted, error, changed = False, str(refusal), None
        result = {'scope': 'Own temporary source copies only; no gameplay or engine execution.',
                  'wrapper_sha256': digest(raw_wrapper),
                  'outer_source_sha_unchanged': digest((root / OUTER).read_bytes()) == digest(originals[OUTER]),
                  'original_controls': before['accounting']['control_provisional_bytes'],
                  'mutated_controls': changed, 'mutant_was_accepted': accepted, 'refusal': error}
        if accepted == expect_refusal:
            raise AssertionError(result)
        return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wrapper', type=Path)
    parser.add_argument('--expect-refusal', action='store_true')
    args = parser.parse_args()
    print(json.dumps(run(args.wrapper, args.expect_refusal), indent=2))
