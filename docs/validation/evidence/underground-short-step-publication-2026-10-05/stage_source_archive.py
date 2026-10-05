#!/usr/bin/env python3
"""Restore exact ignored historical import witnesses; no runtime/source authority replacement."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[4]
ARCHIVE = Path('godot/demo/assets/underground-matrices/mole-grip-v3.inputs')
PALETTE = ROOT / 'godot/demo/assets/underground-matrices/mole-grip-v3.ugpal'
PALETTE_SHA = '08de54533d28b1a45a2e171180a0ca68812912f67c9b7294bf26c25eec424cda'
PARSER = ROOT / 'tools/export_underground_envelopes.py'

def sha(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        while chunk := stream.read(1048576): result.update(chunk)
    return result.hexdigest()

def run(original):
    assert sha(PALETTE) == PALETTE_SHA
    spec = importlib.util.spec_from_file_location('source_archive_parser', PARSER)
    module = importlib.util.module_from_spec(spec); sys.modules[spec.name] = module; spec.loader.exec_module(module)
    with PALETTE.open('rb') as stream:
        metadata = module.PaletteSource(stream, PALETTE_SHA).metadata
    rows = [metadata['manifest'], *metadata['sources']]
    assert len(rows) <= 2049
    result = {}
    for row in rows:
        name = row['path']
        if not (name.startswith('res://.godot/imported/') or name.startswith('res://demo/assets/') and name.endswith('.import')):
            continue
        expected = row['sha256']
        assert len(expected) == 64 and all(c in '0123456789abcdef' for c in expected)
        relative = ARCHIVE / (expected + '.input')
        source, target = original / relative, ROOT / relative
        assert source.is_file() and not source.is_symlink() and source.stat().st_size <= 268435456 and sha(source) == expected
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.open('rb') as src, target.open('xb') as dst: shutil.copyfileobj(src, dst, 1048576)
        assert not target.is_symlink() and sha(target) == expected
        result[str(relative)] = {'sha256':expected,'bytes':target.stat().st_size,'source':str(source)}
    record = {'palette': PALETTE_SHA, 'parser': sha(PARSER), 'archive_rows': result, 'scope':'Historical disk-only source imports; actual unchanged source verifier remains mandatory.'}
    with (Path(__file__).parent / 'source-archive-stage.json').open('x') as stream: json.dump(record,stream,indent=2); stream.write('\n')
    print(len(result),'exact archive inputs',sum(row['bytes'] for row in result.values()),'bytes')

if __name__ == '__main__': run(Path(sys.argv[1]).resolve())
