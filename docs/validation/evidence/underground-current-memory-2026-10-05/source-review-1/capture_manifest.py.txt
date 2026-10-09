#!/usr/bin/env python3
"""Author-only fixed-checkpoint capture. Normal memory checks never run Git."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[4]
E = Path(__file__).resolve().parent
CHECKPOINT = 'db03b1f7955afedb0aba87d1715498aaedca1623'
OLD = 'docs/validation/evidence/underground-room-memory-integration-2026-10-05/route-owner-manifest.json'
S = 'docs/validation/evidence/underground-short-work-step-runtime-2026-10-05'
T = 'docs/validation/evidence/underground-short-step-itinerary-2026-10-05'
A = 'docs/validation/evidence/underground-surface-anchor-lifecycle-2026-10-05'
Q = 'docs/validation/evidence/underground-short-step-publication-2026-10-05'


def sha(raw): return hashlib.sha256(raw).hexdigest()


def main():
    assert subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip() == CHECKPOINT
    old = json.loads((ROOT/OLD).read_bytes())
    sources = {key: dict(row) for key,row in old['sources'].items()}
    witnesses, versions = {}, {}
    snapshots = E/'predecessors'; snapshots.mkdir(exist_ok=True)

    def historical(path, expected):
        if expected in versions:
            assert versions[expected]['path'] == path
            return versions[expected]
        for relative,digest in witnesses.items():
            if digest == expected:
                raw = (ROOT/relative).read_bytes()
                break
        else:
            for revision in ('ca1edc3f', '116f2f2e', '912de685', 'b2527d79', CHECKPOINT):
                raw = subprocess.check_output(['git','show',revision+':'+path],cwd=ROOT)
                if sha(raw) == expected: break
            else: raise ValueError('unlocated original source '+path+' '+expected)
        assert sha(raw) == expected
        target = snapshots/(Path(path).stem+'-'+expected[:12]+'.gd.txt')
        if target.exists(): assert target.read_bytes() == raw
        else: target.write_bytes(raw)
        relative = str(target.relative_to(ROOT)); witnesses[relative] = expected
        versions[expected] = dict(path=path, locator=relative, sha256=expected)
        return versions[expected]

    def source(path):
        name = 'short_program' if path.endswith('work-step-v1/source_program.gd') else Path(path).stem
        if name in sources: assert sources[name]['path'] == path
        sources[name] = dict(path=path, sha256=sha((ROOT/path).read_bytes()))

    def pin(relative, expected=None):
        raw = (ROOT/relative).read_bytes(); actual = sha(raw)
        if expected is not None and expected != actual:
            assert relative.startswith('godot/') and relative.endswith('.gd'), (relative,expected,actual)
            historical(relative, expected)
        else:
            assert relative not in witnesses or witnesses[relative] == actual
            witnesses[relative] = actual
        if relative.startswith('godot/') and relative.endswith('.gd'): source(relative)

    def rows(relative):
        pin(relative)
        for path,row in json.loads((ROOT/relative).read_bytes()).items():
            locator = row.get('locator',path) if isinstance(row,dict) else path
            expected = row['sha256'] if isinstance(row,dict) else row
            pin(locator,expected)
            if path.startswith('godot/') and path.endswith('.gd'):
                source(path)
                if locator != path: versions[expected] = dict(path=path,locator=locator,sha256=expected)

    for p,h in old['witnesses'].items(): pin(p,h)
    for group in ('baseline','publisher_predecessors','route_predecessors'):
        for row in old[group].values(): pin(row['locator'],row['sha256'])
    pin(OLD)
    for path in (ROOT/'docs/validation/evidence/underground-room-itinerary-census-2026-10-05').glob('*.gd.txt'):
        pin(str(path.relative_to(ROOT)))
    for row in old['sources'].values():
        source(row['path'])
        if sha((ROOT/row['path']).read_bytes()) != row['sha256']: historical(row['path'],row['sha256'])
    for folder in (S,T,A,Q): pin(folder+'/census.py')
    for p in (S+'/census.json',T+'/census.json',A+'/source-review-3/census.json',Q+'/census.json',
              S+'/supporting/call-contract.json', S+'/profile-diagnostic-1/mole-worker.ugprof'):
        pin(p)
    for p in ('docs/validation/evidence/underground-work-approach-2026-10-04/census.py',
              'docs/validation/evidence/underground-ground-turn-2026-10-04/census.py'):
        pin(p)
    for p in (A+'/predecessor/manifest.json',A+'/constructor-source-sha256.json',Q+'/artifact-sha256.json'):
        rows(p)
    for p in ('docs/validation/evidence/underground-route-owner-composition-2026-10-04/inherited-sha256.json',
              'docs/validation/evidence/underground-route-owner-composition-2026-10-04/constructor-source-sha256.json',
              'docs/validation/evidence/underground-route-owner-composition-2026-10-04/engine-lifetime/source-sha256.json',
              'docs/validation/evidence/underground-route-owner-composition-2026-10-04/predecessor/manifest.json'):
        rows(p)
    pin(S+'/supporting/predecessors.json')
    for name,row in json.loads((ROOT/S/'supporting/predecessors.json').read_bytes())['sources'].items():
        pin(S+'/'+row['snapshot'],row['sha256']); source(row['path'])
        versions[row['sha256']] = dict(path=row['path'],locator=S+'/'+row['snapshot'],sha256=row['sha256'])
    pin(Q+'/baseline.json')
    for p,row in json.loads((ROOT/Q/'baseline.json').read_bytes())['sources'].items():
        pin(row['locator'],row['sha256']); source(p)
        versions[row['sha256']] = dict(path=p,**row)
    for p in json.loads((ROOT/S/'census.json').read_bytes())['source_sha256']: source(p)
    for p in ('godot/scripts/core/underground_motion_clock.gd','godot/scripts/core/underground_connector_contacts.gd'):
        source(p)
    for row in old['sources'].values():
        if sha((ROOT/row['path']).read_bytes()) != row['sha256']: historical(row['path'],row['sha256'])
    phase='docs/validation/evidence/underground-room-phases-2026-10-04/census.json'
    pin(phase)
    for name in json.loads((ROOT/phase).read_bytes())['source_sha256']:
        source(sources[name]['path'] if name in sources else 'godot/scripts/core/'+name+'.gd')
    legacy_tool = snapshots/'underground_motion_memory.py.txt'
    raw = subprocess.check_output(['git','show',CHECKPOINT+':tools/underground_motion_memory.py'],cwd=ROOT)
    if legacy_tool.exists(): assert legacy_tool.read_bytes() == raw
    else: legacy_tool.write_bytes(raw)
    pin(str(legacy_tool.relative_to(ROOT)))
    manifest = dict(checkpoint=CHECKPOINT,sources=dict(sorted(sources.items())),witnesses=dict(sorted(witnesses.items())),
        historical_versions=versions,previous_current=old['sources'],baseline=old['baseline'],
        publisher_predecessors=old['publisher_predecessors'],route_predecessors=old['route_predecessors'])
    target=E/'manifest.json'; target.write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(dict(manifest_sha256=sha(target.read_bytes()),sources=len(sources),witnesses=len(witnesses),versions=len(versions))))


if __name__ == '__main__': main()
