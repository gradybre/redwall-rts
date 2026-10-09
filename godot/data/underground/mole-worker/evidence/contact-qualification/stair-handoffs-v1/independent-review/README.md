# Independent offline acceptance — 2026-10-04

Geometry accepted the six frozen executable hashes under source manifest
`c9d5a97579bb0b5867082ff2b96db707532cd8d62cb6c4472347c24680f1b925`.
All 352 source/output/history/inherited entries matched before and after.
The independent run passed 8 + 13 tests, replayed turn terrain (3,048 checks)
and tool/body (1,566), and rebuilt all columns and four source joins. All three
outputs were byte-identical. The complete independent records are copied in
`geometry/`, with their original source locations retained in the records.
`copied-review-sha256.json` pins the copied bytes at their new local locations.

No critical, high or medium finding remained. This acceptance supersedes the
pending-review status in the preserved ADR1142 and review-v1 document snapshots;
those reviewed bytes stay unchanged so every original manifest still resolves.
The geometry-only source result does not grant native/default-backend, existing
gait native yaw, paid part identity, phase/pace, storage or runtime permission.
The 101,368-byte numeric proposal remains unadopted.

The new native harness is a separately owned increment and is excluded from
this offline acceptance and commit.
