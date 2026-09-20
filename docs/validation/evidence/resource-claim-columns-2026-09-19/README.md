# Exact Fishing and Forage claim columns — SAVE-CLAIMS-R01v2

Base52307da (PR156). New exact seven-column Fishing and eleven-column Forage
owner boundaries and a stateless section7 owner0/1 adapter. Fixed512/8192 rows,
exact inactive blanks, Directory namespaces, quantity bounds and source count
checks. Independent publication preserves row identities and Forage ordering
keys; all other sections, scratch and borrowed bindings remain unchanged.

Restore requires a held clock through the adapter. No Inventory dependency,
old rebuilder, purge, order-key refresh or live mutator is invoked. Full-world
activation still requires new checked cross-section claim reconciliation and
complete save orchestration. No schema/wire change, no gameplay admission change.

Parent15tests include public collection/release/re-admission continuation and
public Job/Expedition destruction followed by exact claim restore and normal
stale purge. Unrelated state, Directory and Jobs are snapshotted. Six independent
preimplementation Python wire goldens cover empty/sparse/full fixed tables.
Framing probes plus existing codec regression do not prove a full-file writer.

First focused run failed on a parent fixture Array typing error, fixed and log
retained. Focus before final test additions330/5182/0; full4797/189528/0 with
baseline553objects/33resources unchanged. Finalfocus331/5223/0. Editor import and
all15static checks pass. Independent source review found no functional blocker;
three registry/documentation defects resolved, explicit scope/test dispositions
recorded. Review transport returned fenced JSON, recovered under strict exact-
path/input-SHA checks after owner stopped; original invalid result retained.

Allocation bounds3P owners,5P adaptercapture,4P apply with P12800/434176 include
constructor allocations and publication duplicates. Excludes other-section
state, borrowed worlds, external snapshots and object overhead. No RSS claim.
Old executable source is unchanged; four historical comments now mark legacy
load helpers explicitly. Canonical registry remains602fields/553packed columns.

All four required mutants were killed (6/3/2/2 failing tests, each15tests/1531
assertions); correct production hashes restored. Results are in mutation-results.json. Exact-head CI35485149614 passed4798tests/189569assertions/0failures with
unchanged553objects/33resources. PR157 merged atccb3da6; whole-section, full-save and first-playable gates stay open.
