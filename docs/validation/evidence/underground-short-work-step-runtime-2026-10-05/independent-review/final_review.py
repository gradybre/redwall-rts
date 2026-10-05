#!/usr/bin/env python3
"""Final accepted 1168 review receipts, built from exact read-only candidate2 bytes."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import unittest

ROOT = Path('/Users/brendan/Developer/redwall-rts-codex-ug-short-work-step-runtime')
E = ROOT / 'docs/validation/evidence/underground-short-work-step-runtime-2026-10-05'
P = ROOT / 'godot/data/underground/mole-worker/work-step-v1'
OUT = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def pin(path):
    return {'path': str(path.relative_to(ROOT)), 'sha256': sha(path)}

def main():
    source = E / 'source-review-2/source-sha256.json'
    assert sha(source) == '1bc01db521fcf1a3a806e1f42385d465773df46609c9eab1a5c2b6dab809cf9b'
    pins = json.loads(source.read_text())
    assert all(sha(ROOT / path) == expected for path, expected in pins.items())
    census = load('final_1168_census', E / 'census.py')
    result = census.build()
    assert json.loads(json.dumps(result)) == json.loads((E / 'census.json').read_text())
    assert result['profile_control']['counted_logical'] == 3571
    assert result['pure_static_paths']['underground_routes:source_work_leaf_refusal']['bytes'] + 48 == 344
    (OUT / 'final-census.json').write_text(json.dumps(result, indent=2) + '\n')
    mutations = []
    for label, name, before, after in (
        ('short_literal', census.S, 'static func uses(actual: Profiles) -> bool:',
         'static func uses(actual: Profiles) -> bool:\n\tvar _scratch: Array = [' + ','.join(['0']*4096) + ']'),
        ('routes_literal', census.R, 'func advance_tick(tick: int) -> int:',
         'func advance_tick(tick: int) -> int:\n\tvar _scratch: Array = [' + ','.join(['0']*4096) + ']'),
        ('driver_initializer', census.D, 'var _pose: PackedInt32Array = PackedInt32Array([0, 0, 0])',
         'var _pose: PackedInt32Array = PackedInt32Array([' + ','.join(['0']*65536) + '])'),
        ('profile_initializer', census.P, 'var header: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])',
         'var header: PackedInt64Array = PackedInt64Array([' + ','.join(['0']*4096) + '])'),
    ):
        text = census.path(name).read_text()
        assert before in text
        try:
            census.build({name: text.replace(before, after, 1)})
        except ValueError as error:
            mutations.append({'mutation': label, 'refused': True, 'message': str(error)})
        else:
            raise AssertionError(label)
    (OUT / 'corrected-allocation-probes.json').write_text(json.dumps(mutations, indent=2) + '\n')
    native = load('final_1168_native', P / 'run_canonical.py')
    verification = native.validate(E / 'native-4')
    assert verification == json.loads((E / 'native-4/verification.json').read_text())
    tests = load('final_1168_native_tests', P / 'test_run_canonical.py')
    tests.REPLAY = E / 'native-4'
    with (OUT / 'native4-tests.log').open('w') as log:
        tested = unittest.TextTestRunner(stream=log, verbosity=1).run(unittest.defaultTestLoader.loadTestsFromModule(tests))
    assert tested.wasSuccessful() and tested.testsRun == 15
    before = json.loads((E / 'native-4/sources-before.json').read_text())
    assert before == json.loads((E / 'native-4/sources-after.json').read_text())
    assert all(Path(path).is_file() and sha(Path(path)) == expected for path, expected in before.items())
    native_files = ['sources-before.json', 'sources-after.json', 'invocation.json', 'report.json',
                    'native.bin', 'verification.json', 'spec.json', 'native.log', 'engine-native.log',
                    'import.log', 'engine-import.log']
    invocation = json.loads((E / 'native-4/invocation.json').read_text())
    assert all(invocation[k] is True for k in ('source_unchanged','override_restored','import_sidecars_restored'))
    assert all(c['exit'] == 0 and c['raw_diagnostic'] is False for c in invocation['commands'])
    strict, raw = ('diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)',
                   'log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).')
    summaries = []
    for suite in ('test_underground_profiles.gd', 'test_underground_routes.gd', 'test_underground_world_routes.gd', 'test_mole_profile_driver.gd'):
        text = (E / 'runtime-7' / (suite + '.log')).read_text()
        summary = re.findall(r'^(\d+) test\(s\), (\d+) assertion\(s\), (\d+) failure\(s\)$', text, re.M)
        assert len(summary) == 1 and strict in text and raw in text
        values = list(map(int, summary[0]))
        assert values[2] == 0
        summaries.append(dict(suite=suite, tests=values[0], assertions=values[1], failures=0))
    assert sum(r['tests'] for r in summaries) == 167 and sum(r['assertions'] for r in summaries) == 18407
    runtime = json.loads((E / 'runtime-7/invocation.json').read_text())
    assert all(runtime[k] is True for k in ('source_unchanged','project_restored','assets_restored','registry_restored'))
    assert all(c['exit_code'] == 0 for c in runtime['commands'])
    assert json.loads((E / 'runtime-7/analyzer.json').read_text()) == {}
    assert '0 GDScript warning(s) in 0 of 11 file(s)' in (E / 'runtime-7/analyzer.log').read_text()
    runtime_pins = json.loads((E / 'runtime-7/source-sha256.json').read_text())
    assert all(sha(ROOT / path) == expected for path, expected in runtime_pins.items())
    ancestry = json.loads((OUT / 'source-ancestry.json').read_text())
    assert not ancestry['failed'] and ancestry['counts'] == {'old_v3_prerequisites':509, 'source1164_direct_inputs':19, 'source1164_producers':22}
    assert all(sha(ROOT / path) == expected for path, expected in pins.items())
    acceptance = {
        'schema': 1, 'reviewer': '/root/ug_construction', 'accepted': True,
        'source_runtime_accepted': True, 'sampled_native_replay_accepted': True,
        'world_activation_qualified': False, 'production_publication_qualified': False,
        'native_memory_qualified': False, 'performance_qualified': False,
        'scope': 'ADR1168 component: source protocol6, finite232u programme, legacy programme5 retained, actual canonical Routes/Driver native replay in explicitly unearned test geometry.',
        'source_manifest': pin(source), 'candidate_sources': pins,
        'runtime_modules': {path:digest for path,digest in pins.items() if path in (
            'godot/scripts/core/underground_profiles.gd', 'godot/scripts/core/underground_routes.gd',
            'godot/scripts/core/underground_world_routes.gd', 'godot/data/underground/mole-worker/mole_profile_driver.gd',
            'godot/data/underground/mole-worker/work-step-v1/source_program.gd')},
        'serializer': pin(P / 'assemble_diagnostic.py'), 'ground_serializer': pin(P / 'assemble_ground_diagnostic.py'),
        'source1164_report': pin(ROOT / 'docs/validation/evidence/underground-short-work-step-2026-10-05/source-3/result/step-program.json'),
        'diagnostic_wire': pin(E / 'profile-diagnostic-1/mole-worker.ugprof'),
        'diagnostic_ground_wire': pin(P / 'diagnostic-ground-v1/ground-pace.ugconn'),
        'old_v3_manifest': pin(ROOT / 'godot/data/underground/mole-worker/profile-publication-v3/manifest.json'),
        'ancestry_receipt': {'path':str((OUT/'source-ancestry.json').relative_to(OUT.parents[4])), 'sha256':sha(OUT/'source-ancestry.json'), 'counts':ancestry['counts'], 'historical_live_substitutions':0},
        'native_evidence': {name:pin(E / 'native-4' / name) for name in native_files},
        'native_input_count':len(before), 'native_verification': verification,
        'runtime_evidence': {'invocation':pin(E/'runtime-7/invocation.json'), 'sources':pin(E/'runtime-7/source-sha256.json'),
                             'analyzer':pin(E/'runtime-7/analyzer.json'), 'suites':summaries, 'all_diagnostics_and_leaks':0},
        'independent_replays': {'serializer_tests':6, 'native_tests':15, 'census_tests':30,
                                'all_four_original_R1_mutants_refused':True, 'engine_rerun_by_reviewer':False},
        'logical_memory': {'profile_controls':3571,'profile_logical_ceiling':4096,'moving_helper':877,'turn_helper':504,
                           'work_ready_leaf':344,'profile_pair_delta':1764,'joint':248632,'joint_reservation':262144,
                           'no_new_actor_columns':True, 'foreign_callers_require_root_census':True},
        'findings': [], 'closed_findings': [{'id':'R1','severity':'MEDIUM','waived':False,
            'problem':'Literal and initializer growth escaped the original constructor/numeric-only census.',
            'closure':'Exact complete code tokens, complete local type topology and literal payloads; all original and added growth mutants refuse.'}],
        'remaining': ['Root current-consumer publication/whole-pack accounting', 'Actual paid next-cell composition',
                      'Finite World activation', 'Target-hardware performance', 'Native memory measurement']}
    (OUT / 'acceptance.json').write_text(json.dumps(acceptance, indent=2) + '\n')
    print(json.dumps({'accepted':True,'source_manifest':sha(source),'acceptance_sha256':sha(OUT/'acceptance.json'),
                      'runtime': [167,18407,0],'native':verification,'world_activation_qualified':False},indent=2))

if __name__ == '__main__':
    main()
