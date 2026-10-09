# Paid workpiece memory reconciliation — 2026-10-04

Decision1134 adds a separate29,928-byte contribution for both packed workpiece
banks, immutable source rows and fixed/helper/stream/native allowances. None
is borrowed from the already assigned524,288-byte binding reservation. The
current source-derived pack is99,991,614 bytes including the existing reserve,
leaving8,386 bytes under the unchanged100,000,000-byte ceiling. These are
conservative engineering counts, not measured runtime admission or RAM.

The first independent packet ran160 tests against the three exact pending
source pins and rejected eight additional allocation/member/width mutants.
Its original Workpieces source was e6452fde. The final bind-refusal cleanup
changed it to7a462a41 without changing storage; the normal integrated run at
b518ca1f repeated all160 tests against that final source and passed. The root
final census is retained separately. The paired Placement helper high-water
was572/576 bytes; its total controls remain1,895/2,048.

`normal-integrated-v1` retains the actual run, including the initial READY07
failure on its old hard-coded subtotal. The follow-up changes only the derived
architecture ledger/arithmetic and generated reports, preserving every older
trail entry and charging1134 once. `ledger-followup-v1` passes all six commands:
READY07 reports145 field rows and50 allocation rows; merge gate reports zero
problems; the memory and capacity reports reproduce; the registry covers141
modules/706 field rows/1,044 packed declarations; decision-number validation
passes. The normal capacity tests pass190 checks. Exact commands, pins and
unchanged-source observations are in each invocation record.

The7 source/document/artifact pins in `ledger-followup-v1/invocation.json`
define the final reviewed delta. Component Godot evidence belongs to the
original1134 and1135 packets. This ledger follow-up did not execute a fresh
full Godot suite or measure runtime memory. New delivery/haul guards and stair
programs are not silently included in these figures.
