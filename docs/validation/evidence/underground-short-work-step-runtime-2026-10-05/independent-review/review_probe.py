#!/usr/bin/env python3
"""Read-only independent 1168 pin/census probe; outputs live in the review tree."""
from __future__ import annotations
import hashlib
import importlib.util
import json
from pathlib import Path

AUTHOR = Path('/Users/brendan/Developer/redwall-rts-codex-ug-short-work-step-runtime')
E = AUTHOR / 'docs/validation/evidence/underground-short-work-step-runtime-2026-10-05'
OUT = Path(__file__).resolve().parent

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def main():
    raw = (E / 'source-review-1/source-sha256.json').read_bytes()
    assert digest(raw) == 'b6ebe49bf873ffecc449a34c21cf9b28f92ead250b27df8e33234c1f7a6d6b7a'
    pins = json.loads(raw)
    actual = {path: digest((AUTHOR / path).read_bytes()) for path in pins}
    assert actual == pins
    (OUT / 'original-source-pins.json').write_bytes(raw)
    spec = importlib.util.spec_from_file_location('independent_1168_census', E / 'census.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    result = module.build()
    assert json.loads(json.dumps(result)) == json.loads((E / 'census.json').read_text())
    (OUT / 'census-reproduced.json').write_text(json.dumps(result, indent=2) + '\n')
    findings = []
    for name, target, signature in (
        ('short_source_literal', module.S, 'static func uses(actual: Profiles) -> bool:'),
        ('routes_literal', module.R, 'func advance_tick(tick: int) -> int:'),
    ):
        source = module.path(target).read_text()
        literal = '\n\tvar _scratch: Array = [' + ','.join(['0'] * 4096) + ']'
        changed = source.replace(signature, signature + literal, 1)
        assert changed != source
        try:
            output = module.build({target: changed})
        except ValueError as error:
            findings.append({'name': name, 'refused': True, 'message': str(error)})
        else:
            findings.append({'name': name, 'refused': False,
                             'logical_before': result['profile_control']['counted_logical'],
                             'logical_after': output['profile_control']['counted_logical'],
                             'extra_Array_elements': 4096,
                             'mutated_sha256': digest(changed.encode())})
        (OUT / (name + '.gd.txt')).write_text(changed)
    (OUT / 'allocation-probes.json').write_text(json.dumps(findings, indent=2) + '\n')
    assert {path: digest((AUTHOR / path).read_bytes()) for path in pins} == pins
    print(json.dumps({'pins': len(pins), 'census_exact': True, 'probes': findings,
                      'author_sources_unchanged': True}, indent=2))

if __name__ == '__main__':
    main()
