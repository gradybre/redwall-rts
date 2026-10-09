#!/usr/bin/env python3
"""Stage exact existing assets read-only, run unchanged oracle, restore our staging."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
E = Path(__file__).resolve().parent
SOURCE = Path('/Users/brendan/Developer/redwall-rts-codex-ug-work-approach')
RUNNER = ROOT / 'godot/data/underground/mole-worker/work-approach-v1/run_canonical.py'
RUNNER_SHA = '7d36f92546ce19604a0c2a59422a46675c270c4ff73da3992f2e86ccbb951281'
BAKE = ROOT / 'godot/data/underground/mole-worker/evidence/contact-qualification/high-wall-runtime-sources-v1/bake-spec.json'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            h.update(block)
    return h.hexdigest()


def cleanup(made, directories):
    """Remove our clones and known engine-extracted textures in newly created directories."""
    removed = {}
    for path in reversed(made):
        path.unlink()
    allowed = {'body_l0_metallic_roughness.png', 'body_texture_0.png', 'body_l0_normal.png'}
    for directory in sorted(directories, key=lambda p: len(p.parts), reverse=True):
        for path in directory.iterdir():
            assert path.is_file() and not path.is_symlink() and path.name in allowed, str(path)
            with path.open('rb') as stream:
                assert stream.read(8) == b'\x89PNG\r\n\x1a\n'
            removed[str(path.relative_to(ROOT))] = digest(path)
            path.unlink()
        directory.rmdir()
    return removed


def main():
    assert digest(RUNNER) == RUNNER_SHA
    out = E / 'native-1'
    assert not out.exists()
    bake = json.loads(BAKE.read_bytes())
    rows = [bake['manifest'], *bake['sources']]
    plan = {}
    for row in rows:
        if row['path'].startswith('res://demo/assets/'):
            relative = 'godot/' + row['path'][6:]
        elif row['path'].startswith('res://.godot/imported/'):
            relative = 'godot/demo/assets/underground-matrices/mole-grip-v3.inputs/' + row['sha256'] + '.input'
        else:
            continue
        source, target = SOURCE / relative, ROOT / relative
        assert source.is_file() and not source.is_symlink() and source.stat().st_size < 268435456
        assert digest(source) == row['sha256'], relative
        assert relative not in plan or plan[relative]['sha256'] == row['sha256']
        plan[relative] = {'source': str(source), 'sha256': row['sha256'], 'bytes': source.stat().st_size,
                          'existed': target.exists()}
        if target.exists():
            assert target.is_file() and not target.is_symlink() and digest(target) == row['sha256']
    assert len(plan) <= 256 and sum(r['bytes'] for r in plan.values()) <= 3 * 1024**3
    (E / 'staged-inputs.json').write_text(json.dumps(plan, indent=2) + '\n')
    made, directories = [], set()
    result = {'runner_sha256': RUNNER_SHA, 'initial_attempt': 'Before staging, the unchanged runner refused missing root assets/manifest.json before creating output or launching Godot.'}
    try:
        for relative, row in plan.items():
            if row['existed']:
                continue
            target = ROOT / relative
            parent = target.parent
            while not parent.exists():
                directories.add(parent)
                parent = parent.parent
            target.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(['cp', '-c', row['source'], str(target)], check=True)
            made.append(target)
            assert digest(target) == row['sha256']
        command = [sys.executable, '-B', str(RUNNER), str(out), '--proof',
                   str(ROOT / 'docs/validation/evidence/underground-work-approach-2026-10-04/source-4/approach-program.json')]
        print('running unchanged native canonical oracle with', len(plan), 'verified assets/archive rows', flush=True)
        with (E / 'native-wrapper.log').open('x') as stream:
            status = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT).returncode
        result.update(command=command, exit_code=status)
        assert status == 0, 'native replay failed; inspect retained log'
    finally:
        try:
            result['generated_textures_removed'] = cleanup(made, directories)
        finally:
            result['staged_assets_restored'] = all((ROOT / p).exists() == r['existed'] for p, r in plan.items())
            result['borrowed_sources_unchanged'] = all(digest(Path(r['source'])) == r['sha256'] for r in plan.values())
            (E / 'staging-invocation.json').write_text(json.dumps(result, indent=2) + '\n')
        assert result['staged_assets_restored'] and result['borrowed_sources_unchanged']


if __name__ == '__main__':
    main()
