# Astra disposition of count contract review

B1/B2/B3 accepted: no new authority callback. Structural counts explicitly do not
certify equipment attestation; existing audit/loader retains it. Gear lookup is
bounded but potentially quadratic when nested, so reviewer wording “not bounded”
is overstated; eliminating the nested scan fixes the actual cost concern.
Existing _attesting nesting/unguarded clear deserves separate owner review; this
read adds no callback and refuses when that guard is raised.

B4 accepted: per-row STATE then checked accumulation; earlier overflow can win.
B5 rejected as proposed. No allocation-stability requirement existed, and copying
values into possibly aliased caller fields can corrupt the four results. The
actual Godot4.7.2 probe confirms shared fields observe element writes. V2 explicitly
replaces fields with independent staging buffers, supports aliasing and states
retained-reference semantics. Raw probe/source retained; source acceptance must
check this with an actual aliased-target regression.
B6 clarified rather than relaxed: this API requires a catalog-composed committed
store. Registration and positive quantity remain hard checks; partially restored
or zero-live records explicitly refuse, rather than legitimizing unknown items.
No authoritative mutation or save-validation behavior changes.
Journal BUSY, explicit highwater/occupancy/generation checks and separate private
scratch comparisons accepted. V2 is accepted for implementation; independent
source review will confirm contract consumption and actual behavior.
