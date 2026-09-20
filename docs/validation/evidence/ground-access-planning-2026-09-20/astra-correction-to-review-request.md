# Correction to Astra's follow-up request

The follow-up request correctly points out that section9 already has a codec defining nine Movement cursor/admission columns, and that an unsized/absent section9 writer is an inaccurate description. However, its phrase "live navigation capture/restore implementation" was wrong: the recently accepted planner capture work is **job_planner.gd / section8**, not navigation.gd / section9. Current navigation.gd and movement.gd do not yet expose the bulk APIs listed by save_section_navigation.gd's BLOCKER N1; SAVE-COLUMNS-NAVIGATION is ready, not done.

Retain the distinction: the section9 wire format/Record codec and field allocation exist; live Navigation/Movement capture/apply and whole-file disk continuation remain unfinished. The requested missing-journey allowance is still not an acceptable replacement for required full continuation parity. No new runtime fields, bytes or schema changes are authorized by either review.

This correction was recorded after review-a2 began and was not part of its frozen packet. Astra will disposition the result against actual source, including any correction the reviewer independently makes. Do not claim that reviewer saw this note.
