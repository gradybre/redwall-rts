# Corrected source review packet

The six pins in `source-sha256.json` are frozen. The prior packet remains
unchanged in `../source-review-1/`.

The only production change since that packet is the early initialized-owner
guard in both public phase prepare methods. Reentry poisoning still precedes
the nonobserving guard. Missing configured/readiness or Space/Locations/Routes/
WorldRoutes/Budget links return zero before companion field access. No new
field, allocation, scalar local or helper frame is introduced.

The dedicated regression adds fresh, configure-only and each missing-owner
case, verifies no live/candidate/lease mutation and then performs the real
restored-binding phase. The ADR now names the direct Placement prepare API and
Authority's context/observation/final/discard methods, and explicitly separates
iterator metadata from actual Approach permission and 1152 caller accounting.

`candidate-9` in the parent evidence directory passed 12 tests / 736 assertions
with zero failures, strict/raw diagnostics and leaks, and analyzer 0/5. The
paired `final-1` run uses the same corrected pins. Source-counted totals remain
1,895/2,048 controls, 564/576 ordinary preparation, 308/512 iterator and a
691,024-byte maximum sequential cold peak. Run `../census.py` from the actual
repository layout to reproduce; the `.txt` here is a non-executable snapshot.

Independent corrected-source verdict: accepted by root within the component
scope. All six source/test/UID pins matched and the census reproduced exactly.
The complete final author run then passed 173 tests / 17,943 assertions across
seven strict suites, all strict/raw diagnostics/leaks zero, analyzer 0/5 and
complete restoration, without changing the reviewed pins. Byte-exact review
records are in `../independent-review/` with their original source locators.
