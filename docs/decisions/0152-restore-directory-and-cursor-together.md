# 0152 — Restore directory identities and their allocator cursor together

Date:2026-09-19 · Status:Accepted bounded implementation contract

Existing §1 capture and the directory's atomic bulk restore already preserve the
cursor domain including exhaustion. The save layer lacks a consumer joining that
scalar with §3's columns; using the columns-only apply would reuse spent IDs.

[SAVE-D2-R02](../rulings/2026-09-19_save_identity_restore.md) adds a stateless
adapter under the supplied world's actual load barrier. It validates the wire
record, calls the existing atomic owner method and preserves its refusal codes.
It changes no byte format and adds no second authority. The future coordinator
owns matching the clock/directory, full-file validation and rollback; this adapter
alone does not restore a settlement or close SAVE-CAPTURE.
