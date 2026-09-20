# Astra contract-review disposition — draft2 repair

B1 accepted: compiled OWNER_VERSIONS[16] is2. The initial Astra note and first feasibility review were wrong. Contract now pinsversion2 and metadata fault changes2to3; no schema change. Actual engine source-pin probe verifies ownerkey/version/shape and all requested source constants. Historical notes retain their original observations; this correction governs execution.

C1 closed: Section already exposes u8_column/set_u8 and validates u8 bucket count/extent. Priorities and Schedule bridges already use them; the reviewer's suggestion this would be the first byte-column bridge was an input-scope misunderstanding. Actual probe executes Workfield8setter/accessor, valid shape and malformedu8extent refusal. No Section change.

C2 accepted and clarified: memory-extent omission is killed through a direct static predicate call with wrong-lengthmemory and otherwisevalidcolumns. Framed validation rejects earlier; it cannot prove that private static check by itself. Memory-zero substitution remains equivalent and excluded.

C3 closed by parent source reading and actual chained-constant probe: Work.RESIDENT_CAPACITY512, SKILL_COUNT12, reserved3, denominators1000/1000/10000, Gear/Inventorylot16384, Gear/JobsJob8192 andnull-1/0. Independent capacity audit still required after edits.

Additional parent correction: the initial const-line-only preload scan missed the multiline SaveSectionComponentColumns self-preload. The corrected literal multiline scan still finds22nodes/no new bridgecycle, now records allthree baseline self-cycles (IntMath, SaveCodec, SaveSectionComponentColumns). Preserve both artifacts; use proposed-preload-closure-multiline.json. No whole-graph acyclicity claim.

A bounded independent repair confirmation follows before author authorization. No production Work edit yet. Fauna PR165 remains separate and inCI.

Repair confirmation reports no remaining contract blocker. Astra accepts WORK-S4-VALIDATE-R01v1/ADR0175 and authorizes only the bounded two-file implementation. Actual import/checks/source review/CI remain acceptance work.
