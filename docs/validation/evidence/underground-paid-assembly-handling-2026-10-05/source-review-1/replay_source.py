"""Independent bounded 1178 source/native replay; output only in the review worktree."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import unittest

AUTHOR = Path('/Users/brendan/Developer/redwall-rts-codex-ug-timber-program-binding')
SOURCE = AUTHOR/'godot/data/underground/mole-worker/qualified-assembly-v1'
EVIDENCE = AUTHOR/'docs/validation/evidence/underground-timber-program-binding-2026-10-05/source-review-1'
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(SOURCE))

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def load(name):
    spec = importlib.util.spec_from_file_location('review_'+name, SOURCE/(name+'.py'))
    module = importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

pins = {**json.loads((EVIDENCE/'source-sha256.json').read_text()), **json.loads((EVIDENCE/'outputs-sha256.json').read_text())}
assert all(digest(AUTHOR/path) == value for path,value in pins.items())
modules = [load(name) for name in ['test_assembly','test_native','test_census']]
suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromModule(module) for module in modules)
result = unittest.TextTestRunner(verbosity=2).run(suite)
if not result.wasSuccessful(): raise SystemExit(1)
import compile_assembly as compiler
outputs = compiler.build(SOURCE/'candidate-8', SOURCE/'candidate-8/proof-1.json', SOURCE/'candidate-8/tool-body-1.json')
rebuild = OUT/'rebuilt';rebuild.mkdir(exist_ok=False)
for name,raw in outputs.items():
    assert raw == (SOURCE/'compiled-3'/name).read_bytes(), name
    (rebuild/name).write_bytes(raw)
import run_native as native
verification = native.validate(SOURCE/'native-4')
assert verification == json.loads((SOURCE/'native-4/verification.json').read_text())
import census
counts = census.build()
assert all(digest(AUTHOR/path) == value for path,value in pins.items())
record = {'tests':result.testsRun, 'failures':len(result.failures), 'errors':len(result.errors),
          'source_and_output_pins_unchanged':len(pins), 'compiler_outputs':{name:hashlib.sha256(raw).hexdigest() for name,raw in outputs.items()},
          'native_verification':verification, 'census':counts, 'engine_rerun':False, 'foreign_writes':False}
(OUT/'replay.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
