# Checked reservation totals — RES-TOTAL-R01v2

Base1798854 (PR154). A real public-API fixture reserves6e18 milli from each of
two different item lots for one job. Each lot and both source item totals fit;
the former job-total query wrapped to a negative value. The new cold APIs
return IntMath.IntResult, with nonallocating caller-output variants. Overflow
is explicit; valid claims and their exact save representation are unchanged.
The existing per-lot audit now checks addition before comparing totals.

Independent Opus contract review preceded implementation. An independent Opus
source review accepted semantics and identified an Astra integration cleanup
parse error. Both malformed comment remnants were removed. Original failed
full run and reviewed bad diff remain evidence, not acceptance. The corrected
diff is integration-repaired.diff. Editor imports and focused130tests /
3144assertions /0failures passed again. All15staticchecks passed. Final full
and CI results are recorded below when observed.

The parent authored8newtests and migrated all5oldgettercalls (2job/3lot) to
check ok before value. Source census and scope proof show only3existing
functions changed,3helpers added and the old unchecked helper removed;88other
existing functions are unchanged. skip-checked-add mutant is killed by6of8
newtests (195assertions); exact source SHA restored. Claimed source-only
reviewer assertion that the exact-I64MAX case would also kill this mutant was
not inferred as observed; the runtime kill list is authoritative.

No claim/release/schema change, whole-world audit closure, playable settlement,
full save/load or allocation-performance claim follows from this packet.

Corrected full run:4760tests/186771assertions/0failures. Existing suite shutdown553objects/33resources remains; this packet does not claim to fix it. Exact-head CI pending.
