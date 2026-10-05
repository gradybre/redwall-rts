#!/usr/bin/env python3
"""Evidence-only bounded replay of the unchanged LSP client's dependent UI script order."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import time
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[4]
FILES = (
    'demo/demo_village.gd', 'demo/ui/demo_stall_banner.gd',
    'scripts/systems/ui_manager.gd', 'scripts/ui/ui_resident_card.gd',
    'scripts/ui/ui_resident_snapshot.gd', 'scripts/ui/ui_shell.gd',
    'scripts/ui/ui_specimen.gd',
)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--port', type=int, default=6465)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location('exact_warnings', ROOT/'tools/gdscript_warnings.py')
    warnings = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(warnings)
    editor_log = Path(os.environ.get('TMPDIR', '/tmp'))/f'gdscript_warnings_editor_{args.port}.log'
    trace = []
    started = time.monotonic()
    class TracedLsp(warnings.Lsp):
        def send(self, message):
            if message.get('method', '').startswith('textDocument/'):
                raw = editor_log.read_text()
                trace.append({'seconds': round(time.monotonic()-started, 6),
                    'method': message['method'], 'uri': message['params']['textDocument']['uri'],
                    'raw_editor_bytes': editor_log.stat().st_size,
                    'raw_diagnostics_so_far': re.findall(r'^.*(?:SCRIPT ERROR:|^ERROR:).*$', raw, re.M)})
                (args.out/'trace.json').write_text(json.dumps(trace, indent=2)+'\n')
            return super().send(message)
    warnings.Lsp = TracedLsp
    paths = [ROOT/'godot'/name for name in FILES]
    pins = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    found = warnings.collect_all(SimpleNamespace(port=args.port, godot='godot'), paths,
                                 ROOT/'godot', ROOT/'godot')
    raw = editor_log.read_bytes()
    (args.out/'editor.log').write_bytes(raw)
    (args.out/'diagnostics.json').write_text(json.dumps(found, indent=2)+'\n')
    result = {'files': list(FILES), 'source_sha256': pins, 'diagnostics': found,
        'source_unchanged': pins == {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
        'raw_diagnostics': re.findall(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):.*$', raw.decode(), re.M)}
    (args.out/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))
    return 1 if found or result['raw_diagnostics'] or not result['source_unchanged'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
