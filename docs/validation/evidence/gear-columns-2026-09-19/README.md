# Exact Gear columns — SAVE-GEAR-R01v2

Base d8af51e (PR155). Exact12canonical arrays, bare row identity, equipped flags,
claims and wear values. Capture validates payload plus source counts/heap/cache;
restore privately validates and stages then publishes independent columns, heap,
3counts and5catalog IDs. Caller must bind before installing equipped rows.
Separate section7 owner2 adapter, same schema/wire, held clock on apply and
matching supplied idle Inventory when bound. Full-world reconciliation remains.

Independent feasibility, contract and source reviews completed. Source review
found no correctness blocker;6testgaps closed with4extra tests and fuller
collaborator snapshots. Parent now owns23newtests. Integratedfocus159/3292/0;
full4779/187779/0 before4test additions. Finalfocus163/3551/0 with23newtests.
15static checks and editor import pass;29module dependency closure has no cross
module cycle (four pre-existing self-preloads).

3mutants killed (equipped publication2failures, duplicate-lot2, source-derived1),
each ran23tests/1267assertions; correct productionSHA restored. Full initial
shutdown593objects/33resources included40newfixture-cycle leaks. Public fixture
teardown removes these; focusedcount310->270. FinalCI must confirm fullbaseline
553objects/33resources alongside final4783tests; no leak fix to production claimed.

Literal independent wire goldens prove block sizes464 atR8 and688256 atR16384,
exact populated/empty columns and framing. These probes plus codec regression
do not prove fullworld loading or disk rollback. Packed allocation bounds
verified against source, not measured peak/RSS. Both owner counts and wire
classification remain within existing canonical602fields/553packed columns.

No first-playable, artwork/native-client, whole-section or full-save acceptance
follows from this isolated owner change. Exact-head CI pending.
