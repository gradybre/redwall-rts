# Astra disposition — SAVE-J2-R01v2

Independent source review reports no blocking findings. Full suite4670 tests/181533 assertions/0 failures; focused293/6431/0; all15 specification checks pass. Historical first focused run caught one old 29-count expectation; corrected to35 and rerun.

Four advisories do not require behavior changes: field+1 count adjacency is explicitly frozen by SAVE-J2-R01 and registry tests, so a new nested pair table is unnecessary. Richer refusal detail can be added when the full load coordinator consumes it; current codes and field names are distinct. The scalar metadata currently has exact count1 and scalartrue, verified by the artifact/compiled declaration checks; stronger future mutation coverage is optional. The shortened header cites the designated pending-service primary table and decision0146, and the directory namespace remains documented with DIRECTORY_CAPACITY/NULL_GENERATION; historical reasoning remains in decisions0120/0146. No source changes followed review.

Transport recovery was necessary: the author timed out at15minutes, owner stopped, and returned no patch; Astra implemented directly. Reviewer owner stopped successfully but malformed JSON had four unescaped quotes inside its report. Those four quotes alone were escaped to parse the same report; raw public response, repaired bundle, original result and input hashes are retained. No worker thinking was read.

Acceptance is structural codec/format and zero-tail scheduling repair. Live capture/apply remain J2 refusals; full-world hash, disk restore, native art and first playable remain open. Existing suite shutdown553objects/33resources remains an unresolved baseline issue.
