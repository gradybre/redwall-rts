# 1177 — Resident snapshot must not preload its consumer card

Date: 2026-10-05 · Status: correction under validation

The full ca1 integration suite passed, but its complete LSP analyzer opened
two UI dependency closures with eight raw script/load errors despite reporting
zero warnings. A fresh clean-import retry reproduced the errors. A bounded
seven-file probe reproduced the five errors from opening the stall banner.
The evidence remains in `underground-route-integration-check-2026-10-05`;
the failed raw-editor gates are not waived.

Source inspection found an actual circular preload: UiResidentCard constructs
UiResidentSnapshot, while UiResidentSnapshot preloads UiResidentCard for two
label arrays and integer percentage formatting. Move that shared vocabulary
and the exact formatter to the snapshot read model. The card keeps its existing
public constants and percent_text API as aliases/delegation. Need values,
rates, rounding, captions, identity checks and captured rows remain unchanged.
No new authoritative state or per-capture allocation is introduced.

This removes a real dependency cycle. Its relationship to the observed editor
failure must be tested with the same ordered LSP probe, existing card/snapshot
tests and the complete analyzer. A clean limited probe alone does not establish
that the previous full-analyzer failure is closed.

## Separate preload edges and reproduced correction

Candidate 2 removed the card/snapshot cycle but reproduced all five bounded
banner errors. That cycle alone did not explain or resolve the failure.
The stall banner also preloaded the UIManager autoload only to read the
`CLOCK_OVERLOADED` notice code. UiNotices now owns that unchanged shared
string; UIManager retains its public constant alias, and the banner imports
UiNotices directly. The specimen's unused UiShell preload is removed.
Candidate 3 ran the same ordered seven-file LSP probe after a clean import:
zero diagnostics and no raw editor errors. The complete analyzer remains a
required gate; limited probe success is not a waiver.

The geometry agent independently reviewed all six changed files at the exact
hashes in `underground-ui-preload-2026-10-05/source-review.json`. The original
percentage arithmetic/assertion, labels, fields, notice identity and public
consumer APIs are preserved. No high or medium correctness finding remained.
Candidate 1's import crash and candidate 4's missing-file reimport error are
retained. The latter named an existing 381309-byte PNG whose post-run hash was
unchanged; candidate 5 retries without source changes and still enforces the
same raw import gate.

Candidate 5 completes all six existing UI suites: 318 tests / 4635 assertions,
zero failures/unexpected diagnostics/leaks. The full analyzer reports zero
warnings in1258 files but the raw editor gate fails with twelve UiSpecimen /
UiRegistry load-error lines. That gate remains open. UiRegistry imports only
IntMath; another cycle is not assumed. Investigate document open/close lifetime
in an isolated own checkout before making any analyzer change.
