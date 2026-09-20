# Author repair request a2 — same GROUND-CLEARANCE-R01v1

Actual import passes. Focus-a1 executes67tests2602assertions with one semantic failure and no engine errors: successful route_clearance_into leaves REQUEST_NOT_READY diagnostic from prior failed read. Add explicit _last_refusal=REFUSE_NONE on successful ready read. Preserve the test that caught it.

Complete existing contract witnesses while repairing, without changing production policy:
- Use actual Transform.state_bytes() before/after refusal, not only authoritative_digest. Add missing Movement.speed_of snapshot alongside existing public phase/remainder/cursor/admission getters. A typed helper may return Array[int] in explicit documented order for those public values; no private state access or new production accessor.
- Base production refusal for each four starter species: snapshot public movement state, entire Transform state_bytes, travelling count and navigation request descriptor ID/generation/refcount before/after each admission. Construct admission/contact before snapshot to isolate the operation.
- Both idle mismatches: same preservation checks, not phase alone.
- Active mismatch: same full preservation, including speed and byte-exact Transform. Keep verified advancement before and after failure.
- Getter: assert out.ok/error and Navigation diagnostic on each nonready refusal; success after failure clears out.error and diagnostic. Preserve all existing phase witnesses and class1/class2 values. Assert request identity and observable route generation/refcount unchanged across ready reads. No public cache-use accessor exists: source review covers that write absence.
- Add invalid profile and unbound contact priority against an otherwise clear ready mismatched route, plus mismatch before wrong START (existingwrongEND covers onlyend). Ensure invalid profile fixture reader retains parent refusal.

Keep old tests/assertions intact. Helpers concise, typed, bounded. Production fix only navigation.gd; other edits only new test_movement_clearance.gd. No changes to Movement/fixture/old suites are needed. Return <=500-line standard unified diff at repair-a2.patch with correct contiguous context. Prior patch was applied with exact-byte unique-hunk framing normalization (no semantics) because an interior test hunk lacked trailing context. Do not claim execution.
