# Rejected clock accounting checker

Independent read-only review of the exact first-pass pins in `source-sha256.json`. Its six provided tests passed in 2.121 seconds, but the three retained source mutants were all accepted by the normal whole-pack `build` path at the same 1298-byte helper estimate and 99,998,782-byte global declaration. The mutants add an executable million-element `range` Array, a used `duplicate ()` copy with legal whitespace, or a local Array literal. `review.json` records those outcomes; no root or production file was changed.

The checker therefore did not enforce the claimed allocation bound for modified source. This was reported as the sole medium finding. The corrected complete-executable pin and repeated original witnesses are reviewed in `../review-v2/`.
