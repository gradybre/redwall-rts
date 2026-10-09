#!/usr/bin/env python3
"""Regression tests for LSP document lifetime, complete replies and raw editor failures."""
import argparse
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import gdscript_warnings as analyzer
REAL_DRAIN = analyzer.Lsp._drain


class FakeLsp:
    def __init__(self, _port=0):
        self.diagnostics = {}
        self.findings = {}
        self.buf = b""
        self.messages = []
        self.replies = []
        self.sock = self
        self.closed = False
        self.missing = None
        self.republish = False

    def close(self):
        self.closed = True

    def send(self, message):
        self.messages.append(message)

    def pump(self, _deadline, uri=None):
        if uri is None:
            return False
        self.replies.append(uri)
        if uri == self.missing:
            return False
        self.diagnostics[uri] = []
        if self.republish and len(self.replies) > 1:
            for findings in ([{"message": "dependent diagnostic"}], []):
                message = {"method": "textDocument/publishDiagnostics", "params": {
                    "uri": self.replies[0], "diagnostics": findings}}
                data = json.dumps(message).encode()
                self.buf += b"Content-Length: %d\r\n\r\n" % len(data) + data
            REAL_DRAIN(self, uri)
        return True


class AnalyzerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.files = [self.root / "dependency.gd", self.root / "consumer.gd"]
        for path in self.files:
            path.write_text("extends RefCounted\n", encoding="utf-8")

    def test_dependencies_remain_open_and_every_file_has_fresh_reply(self):
        client = FakeLsp()
        client.diagnostics[self.files[0].as_uri()] = [{"message": "stale"}]
        found, done = {}, []
        with patch.object(analyzer, "Lsp", return_value=client):
            analyzer.collect(self.files, self.root, self.root, 1, found, done)
        self.assertEqual(client.replies, [p.as_uri() for p in self.files])
        self.assertEqual(done, self.files)
        self.assertEqual(found, {})
        methods = [m["method"] for m in client.messages]
        self.assertEqual(methods, ["initialize", "initialized", "textDocument/didOpen", "textDocument/didOpen"])
        self.assertTrue(client.closed)

    def test_late_dependency_diagnostic_is_not_lost(self):
        client = FakeLsp()
        client.republish = True
        found, done = {}, []
        with patch.object(analyzer, "Lsp", return_value=client):
            analyzer.collect(self.files, self.root, self.root, 1, found, done)
        self.assertEqual(found, {"dependency.gd": [{"message": "dependent diagnostic"}]})
        self.assertEqual(client.diagnostics[self.files[0].as_uri()], [])

    def test_observed_dependency_warning_survives_eof_and_retry(self):
        class EofLsp(FakeLsp):
            def pump(self, deadline, uri=None):
                result = super().pump(deadline, uri)
                if uri is not None and len(self.replies) == 2:
                    raise analyzer.EditorCrashed("EOF after dependency warning")
                return result
        client = EofLsp()
        client.republish = True
        found, done = {}, []
        with patch.object(analyzer, "Lsp", return_value=client):
            with self.assertRaises(analyzer.EditorCrashed):
                analyzer.collect(self.files, self.root, self.root, 1, found, done)
        self.assertEqual(done, self.files[:1])
        self.assertEqual(found, {"dependency.gd": [{"message": "dependent diagnostic"}]})
        with patch.object(analyzer, "Lsp", return_value=FakeLsp()):
            analyzer.collect(self.files[1:], self.root, self.root, 1, found, done)
        self.assertEqual(done, self.files)
        self.assertEqual(found, {"dependency.gd": [{"message": "dependent diagnostic"}]})

    def test_missing_empty_and_non_script_selections_refuse(self):
        empty = self.root / 'empty'
        empty.mkdir()
        other = self.root / 'readme.txt'
        other.write_text('no scripts')
        for path in (self.root / 'missing.gd', empty, other):
            with self.subTest(path=path), self.assertRaises(SystemExit):
                analyzer.gd_files(self.root, [str(self.files[0]), str(path)])
        self.assertEqual(analyzer.gd_files(self.root, []), sorted(self.files))
        self.assertEqual(analyzer.gd_files(self.root, [str(self.files[0])] * 2), self.files[:1])

    def test_final_drain_collects_a_queued_dependency_update(self):
        class QueuedLsp(FakeLsp):
            def pump(self, deadline, uri=None):
                if uri is None and self.replies:
                    body = json.dumps({"method": "textDocument/publishDiagnostics", "params": {
                        "uri": self.replies[0], "diagnostics": [{"message": "queued"}]}}).encode()
                    self.buf = b"Content-Length: %d\r\n\r\n" % len(body) + body
                    REAL_DRAIN(self, None)
                return super().pump(deadline, uri)
        found, done = {}, []
        with patch.object(analyzer, "Lsp", return_value=QueuedLsp()):
            analyzer.collect(self.files, self.root, self.root, 1, found, done)
        self.assertEqual(found, {"dependency.gd": [{"message": "queued"}]})
        self.assertEqual(done, self.files)

    def test_final_drain_eof_keeps_the_last_file_unfinished(self):
        class FinalEofLsp(FakeLsp):
            def pump(self, deadline, uri=None):
                if uri is None and self.replies:
                    raise analyzer.EditorCrashed("EOF during final drain")
                return super().pump(deadline, uri)
        done = []
        with patch.object(analyzer, "Lsp", return_value=FinalEofLsp()):
            with self.assertRaises(analyzer.EditorCrashed):
                analyzer.collect(self.files, self.root, self.root, 1, {}, done)
        self.assertEqual(done, self.files[:1])

    def test_new_nonempty_reply_cannot_replace_an_earlier_finding(self):
        class WarningLsp(FakeLsp):
            def pump(self, deadline, uri=None):
                result = super().pump(deadline, uri)
                if uri is not None:
                    self.diagnostics[uri] = [{"message": "new"}]
                return result
        found = {"dependency.gd": [{"message": "previous session"}]}
        with patch.object(analyzer, "Lsp", return_value=WarningLsp()):
            analyzer.collect(self.files[:1], self.root, self.root, 1, found, [])
        self.assertEqual(found, {"dependency.gd": [{"message": "previous session"}, {"message": "new"}]})

    def test_retry_harvests_new_findings_for_a_previously_completed_file(self):
        dependency_uri = self.files[0].as_uri()
        class RetryLsp(FakeLsp):
            def pump(self, deadline, uri=None):
                result = super().pump(deadline, uri)
                if uri is not None:
                    body = json.dumps({"method": "textDocument/publishDiagnostics", "params": {
                        "uri": dependency_uri, "diagnostics": [{"message": "retry dependency"}]}}).encode()
                    self.buf = b"Content-Length: %d\r\n\r\n" % len(body) + body
                    REAL_DRAIN(self, uri)
                return result
        found, done = {}, self.files[:1]
        with patch.object(analyzer, "Lsp", return_value=RetryLsp()):
            analyzer.collect(self.files[1:], self.root, self.root, 1, found, done)
        self.assertEqual(done, self.files)
        self.assertEqual(found, {"dependency.gd": [{"message": "retry dependency"}]})

    def test_missing_reply_does_not_count_as_completed_and_socket_closes(self):
        client = FakeLsp()
        client.missing = self.files[1].as_uri()
        done = []
        with patch.object(analyzer, "Lsp", return_value=client):
            with self.assertRaises(analyzer.EditorCrashed):
                analyzer.collect(self.files, self.root, self.root, 1, {}, done)
        self.assertEqual(done, self.files[:1])
        self.assertTrue(client.closed)

    def test_raw_errors_parse_warnings_and_singular_plural_leaks_fail(self):
        lines = ["ERROR: missing dependency", " SCRIPT ERROR: Parse Error: bad", "USER WARNING: stray",
                 "Parser Error: bad", "1 ObjectDB instance was leaked", "2 ObjectDB instances were leaked",
                 "1 resource still in use at exit", "2 resources still in use at exit"]
        self.assertEqual(analyzer.editor_findings("\n".join(lines)), lines)
        self.assertEqual(analyzer.editor_findings("Godot Engine\n0 resources still in use at exit\n"), [])

    def test_raw_failure_cannot_be_erased_by_successful_empty_lsp_reply(self):
        log = self.root / "gdscript_warnings_editor_1.log"
        class Editor:
            def __init__(self):
                self.stopped = False
            def terminate(self):
                self.stopped = True
            def wait(self, timeout):
                return 0
        editor = Editor()
        def collect(*_args):
            log.write_text("ERROR: Could not find dependency\n", encoding="utf-8")
        with patch.dict(analyzer.os.environ, {"TMPDIR": str(self.root)}), \
                patch.object(analyzer.subprocess, "Popen", return_value=editor), \
                patch.object(analyzer, "wait_for_editor"), patch.object(analyzer, "collect", side_effect=collect):
            with self.assertRaisesRegex(SystemExit, "raw editor diagnostic/leak"):
                analyzer.run_session(argparse.Namespace(port=1, godot="godot"), self.files, self.root, self.root, {}, [])
        self.assertTrue(editor.stopped)

    def test_clean_crash_retries_only_unfinished_files_without_losing_findings(self):
        calls = []
        def session(_args, files, _project, _editor_root, found, done):
            calls.append(list(files))
            if len(calls) == 1:
                found["dependency.gd"] = [{"message": "original finding"}]
                done.append(files[0])
                raise analyzer.EditorCrashed("test interruption")
            done.extend(files)
        with patch.object(analyzer, "run_session", side_effect=session), contextlib.redirect_stderr(io.StringIO()):
            found = analyzer.collect_all(argparse.Namespace(), self.files, self.root, self.root)
        self.assertEqual(calls, [self.files, self.files[1:]])
        self.assertEqual(found, {"dependency.gd": [{"message": "original finding"}]})


if __name__ == "__main__":
    unittest.main(verbosity=2)
