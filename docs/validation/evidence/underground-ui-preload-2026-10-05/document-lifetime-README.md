# Analyzer follow-up —1180

The1177 UI source correction remains valid; its candidate5 full analyzer still
logged12 raw missing-script errors despite zero LSP warnings. The experiments
here isolate that remaining failure to per-file `textDocument/didClose`.

- `lifetime-ui-original`:16 actual UI scripts, the original close behavior,
  zero LSP warnings but12 raw errors. This is a rejected result.
- `lifetime-ui-retained`: same16 scripts, wrapper suppresses close; no LSP/raw
  finding. Actual script sources remain unchanged.
- `lifetime-full-retained`:1256 scripts after the production tool retains open
  documents; no LSP/raw findings in74.545s. Its `retain_documents:false` means
  no wrapper monkeypatch; the production tool itself retains them.
- `final-tool-1` and `final-tool-2`: clean engine scans, superseded by independent
  protocol-review findings and their corrections. Their source snapshots stay
  beside their actual results.
- `final-tool-3`: final tool SHA256
  `42fe7c00b08e6e054d25bb1b1fad272fca65932c1d7d2e298dfdb8fc6e7c0a02`,
  tests `f0ee24439a32526b7dc7627c681beecf74368bb81338767bada14879cc766ee8`.
  All12 protocol tests pass. Clean cache/editor import passes. The actual CLI
  `python3 -B tools/gdscript_warnings.py --max 0 --port 6470 --json …` reports:

```text
0 GDScript warning(s) in 0 of 1256 file(s)
```

The raw editor and import logs contain zero errors, warnings or leak reports.
The final CLI took73.522s; every captured script, tool, test and project source
is unchanged before/after. The isolated worktree has no staged demo assets.
This is analyzer qualification, not a no-argument gameplay suite result.

Construction independently accepted the final pins after actual framed-message
probes. The first review caught transient/retry/final-queued warning loss and
an inherited missing-path false success. The second found a new dependency
warning published for an earlier completed file after a suffix retry. The
final implementation preserves a non-clearing finding set, harvests the full
completed/requested selection on success or interruption, and rejects empty
selections. The final drain is explicitly bounded to one second; no guarantee
about arbitrarily delayed future notifications is made. Each selected file
still needs a fresh reply and raw errors always fail before retry can overwrite
a log. No diagnostic allowance or test gate was weakened.
