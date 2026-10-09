# ADR1180 independent review — first candidate

The analyzer change was read in the author's isolated worktree. This review
started at the three pins recorded in `probe.json`; the exact reviewed files
are retained here as nonexecuting text. No engine or network socket was
started, and no author worktree file was changed. The existing six protocol
tests passed.

The document-retention change, owned socket/process cleanup, and raw-log
failure-before-retry ordering are appropriate. A raw diagnostic or leak raises
before the next session can truncate the same log. A clean interruption still
uses the existing bounded unfinished-file retry.

Two findings prevent acceptance of this candidate:

1. **MEDIUM — late LSP diagnostics can be silently lost.** The actual
   `Lsp._drain` replaces the per-URI list. A received nonempty update followed
   by an empty update during a subsequent file's pump leaves `found` empty.
   An update for an earlier file followed by EOF is also lost because the
   late sweep runs only on normal completion; a successful retry then returns
   empty findings. Finally, the actual pump can finish on the last requested
   empty response while another framed dependency warning remains queued;
   collection closes the socket without reading it. `probe.py` exercises all
   three protocol sequences using the actual `_drain` and, for the queued
   case, the actual `pump`. Each reports two completed files and no warning.
   Keep fresh replies separate from a non-clearing received-finding
   accumulator, harvest it even on interruption, and finish a bounded protocol
   drain/barrier before closing a successful session.
2. **MEDIUM — an explicit missing requested path succeeds with zero files.**
   This behavior predates the current diff, but remains relevant to the
   complete-file gate being reviewed. The actual CLI `main` returns zero for
   the fixture's missing path without invoking an editor. Explicit missing,
   empty, or unsupported selections should refuse rather than qualify a
   no-op scan.

Root acknowledged both findings and released its tool only for the bounded
correction. This receipt does not accept that future correction or make any
engine/runtime qualification claim. The original candidate source and all
reproduction outcomes remain here unchanged.
