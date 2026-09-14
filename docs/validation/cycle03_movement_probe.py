#!/usr/bin/env python3
"""Reproduce the current interpolation-error deficiency, NOT fit qualification.

All bounds below are synthetic checker inputs, never production geometry.
Assertions intentionally describe the deficient current checker; a corrected
checker should fail this reproduction rather than be changed to preserve it.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-root', type=Path, required=True)
root = parser.parse_args().source_root.resolve()
sys.path.insert(0, str(root / 'tools'))
import validate_movement_envelopes as checker

assert Path(checker.__file__).resolve() == root / 'tools/validate_movement_envelopes.py'
geometry = checker.load_source_geometry(root)
schema = json.loads((root / 'docs/planning/movement_envelope_schema.json').read_text())
print('DEFICIENCY REPRODUCTION ONLY; synthetic inputs, not production qualification.')
print('source_root:', root)
print('checker_sha256:', hashlib.sha256(Path(checker.__file__).read_bytes()).hexdigest())

record = checker._synthetic_record('cycle3_uncovered_error_probe', 250000, 0)
assert record['data_class'] == 'synthetic_fixture'
record['measurement']['interpolation_error_bound_units'] = 1
record['margin_units']['zero_margin_justification'] = 'Synthetic boundary probe only.'

for margin in (0, 1):
    candidate = copy.deepcopy(record)
    candidate['margin_units'].update(x=margin, y=margin, z=margin)
    document = checker.synthetic_document([candidate], geometry)
    errors = (
        checker.validate_instance(document, schema)
        + checker.file_semantic_problems(document, geometry)
        + checker.record_semantic_problems(candidate, '$.records[0]', geometry)
    )
    assert not errors, errors
    fit = checker.compute_fit(candidate, geometry)
    print(json.dumps({'residual_error_u': 1, 'margin_u': margin,
                      'validation_errors': errors, 'outcome': fit.outcome,
                      'clearance_class': fit.clearance_class,
                      'translated_bounds': fit.translated_bounds,
                      'admitting_class_count': fit.admitting_class_count}, sort_keys=True))
    if margin == 0:
        assert fit.ok and fit.outcome == 'FIT_OK' and fit.clearance_class == 1
        assert fit.translated_bounds == {'x_lo': 0, 'x_hi': 512, 'z_lo': 0, 'z_hi': 512}
    else:
        assert not fit.ok and fit.outcome == 'PLACEMENT_INCOMPATIBLE_AT_OFFSET'
        assert fit.clearance_class is None and fit.admitting_class_count == 0
        assert fit.translated_bounds == {'x_lo': -1, 'x_hi': 513, 'z_lo': -1, 'z_hi': 513}
print('OBSERVED DEFICIENCY REPRODUCED: uncovered error passes; covering it refuses placement.')
