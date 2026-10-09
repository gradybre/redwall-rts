#!/usr/bin/env python3
"""Read-only protocol probes against the frozen ADR1180 analyzer; no engine/socket."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
from unittest.mock import patch

AUTHOR = Path('/Users/brendan/Developer/redwall-rts-codex-ug-analyzer-lifetime')
OUT = Path(__file__).resolve().parent
import types
a = types.ModuleType('analyzer_review')
a.__file__ = str(OUT / 'gdscript_warnings.py.txt')
exec(compile(Path(a.__file__).read_bytes(), a.__file__, 'exec'), a.__dict__)
source_pins = {p: hashlib.sha256((OUT / (Path(p).name + '.txt')).read_bytes()).hexdigest() for p in (
    'tools/gdscript_warnings.py', 'tools/test_gdscript_warnings.py',
    'docs/decisions/1180-analyzer-document-lifetime-and-raw-diagnostics.md')}
project = OUT / 'fixture'
project.mkdir(exist_ok=True)
files = [project / 'dependency.gd.txt', project / 'consumer.gd.txt']
for f in files:
    f.write_text('extends RefCounted\n')
warning = {'range': {'start': {'line': 0, 'character': 0}, 'end': {'line': 0, 'character': 1}},
           'severity': 2, 'message': 'late dependency warning'}

def frame(uri, diagnostics):
    body = json.dumps({'jsonrpc': '2.0', 'method': 'textDocument/publishDiagnostics',
                       'params': {'uri': uri, 'diagnostics': diagnostics}}).encode()
    return b'Content-Length: %d\r\n\r\n' % len(body) + body

class FramedLsp(a.Lsp):
    def __init__(self, mode):
        self.buf = b''
        self.diagnostics = {}
        self.mode = mode
        self.opened = 0
        self.sock = self
        self.closed = False
    def close(self):
        self.closed = True
    def send(self, message):
        pass
    def pump(self, until, want_uri=None):
        if want_uri is None:
            return False
        self.opened += 1
        if self.opened == 2:
            self.buf += frame(files[0].as_uri(), [warning])
            if self.mode == 'clear_late':
                self.buf += frame(files[0].as_uri(), [])
            if self.mode == 'crash_late':
                self._drain(want_uri)
                raise a.EditorCrashed('controlled EOF after actual late diagnostic')
        self.buf += frame(want_uri, [])
        return self._drain(want_uri)

client = FramedLsp('clear_late')
found, done = {}, []
a.collect_documents(client, files, project, project, found, done)
cleared = {'found': found, 'done': len(done), 'expected_warning_count': 1,
           'actual_warning_count': sum(map(len, found.values())),
           'lost': not found}

client = FramedLsp('crash_late')
found, done = {}, []
try:
    with patch.object(a, 'Lsp', return_value=client):
        a.collect(files, project, project, 1, found, done)
except a.EditorCrashed:
    pass
before_retry = dict(found)
late_received = dict(client.diagnostics)
with patch.object(a, 'Lsp', return_value=FramedLsp('clean')):
    a.collect(files[len(done):], project, project, 1, found, done)
crashed = {'found_before_retry': before_retry, 'received_before_crash': late_received,
           'found_after_retry': found, 'done_after_retry': len(done),
           'socket_closed': client.closed, 'lost': not found}

class QueueSocket:
    def __init__(self):
        self.queue = []
        self.closed = False
    def recv(self, _size):
        if self.queue:
            return self.queue.pop(0)
        raise a.socket.timeout()
    def settimeout(self, _value):
        pass
    def close(self):
        self.closed = True

class PumpLsp(a.Lsp):
    def __init__(self):
        self.buf = b''
        self.diagnostics = {}
        self.sock = QueueSocket()
        self.opened = 0
    def send(self, message):
        if message['method'] == 'textDocument/didOpen':
            self.opened += 1
            self.sock.queue.append(frame(message['params']['textDocument']['uri'], []))
            if self.opened == 2:
                self.sock.queue.append(frame(files[0].as_uri(), [warning]))
    def pump(self, until, want_uri=None):
        if want_uri is None:
            return False
        return super().pump(until, want_uri)

client = PumpLsp()
found, done = {}, []
with patch.object(a, 'Lsp', return_value=client):
    a.collect(files, project, project, 1, found, done)
queued = {'found': found, 'done': len(done), 'pending_framed_diagnostics': len(client.sock.queue),
          'socket_closed': client.sock.closed, 'lost': not found and bool(client.sock.queue)}

with patch.object(a.sys, 'argv', ['gdscript_warnings.py', '--project', str(project),
                                str(project / 'missing.gd')]), \
     patch.object(a.subprocess, 'Popen', side_effect=AssertionError('must not start engine')):
    missing_status = a.main()
result = {'source_sha256': source_pins, 'late_then_empty': cleared,
          'late_then_crash_retry': crashed, 'late_after_final_reply': queued,
          'missing_requested_path_exit': missing_status,
          'engines_started': 0, 'production_source_writes': 0}
assert cleared['lost'] and crashed['lost'] and queued['lost'] and missing_status == 0
(OUT / 'probe.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
