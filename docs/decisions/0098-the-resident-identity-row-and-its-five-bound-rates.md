# 0098 — The resident identity row, and five rates from one validated snapshot

2026-09-12 · Implementation of [UI-IDENTITY-R01 and NEED-RATE-R01](../rulings/2026-09-12_resident_header_and_need_rates.md),
adopted as [0097](0097-resident-heading-and-public-need-rates.md).

## What was decided

Three things, all of them forced by the ruling rather than chosen here.

**1. UI-SET-037's 280 px minimum is overridden for the resident template, and only
there.** The identity row is `20 inset | medallion | 8 gap | name column | 8 gap |
44 Close | 20 inset`, giving 48/64/64 px medallions and 172/172/220 px name columns
at NARROW/STANDARD/WIDE. The medallion sits BESIDE the name at all three profiles.
The stacked arrangement that preceded this is deleted, not kept as a fallback.

**2. The detail panel gets a dedicated header/body/footer** instead of extending the
generic vertical flow: a fixed identity header that grows with the measured name, a
scrolling body, and §4.1's fixed 64 px action footer with a 44 px Center view.

**3. All five need rows come from one validated snapshot.** `ui_resident_snapshot.gd`
validates the selected `(slot, generation)` through the directory, resolves its
RESIDENT typed row from that same reference, and copies the five values and rates at
one boundary. No rate formula lives in the UI.

## Why the old composition could not stay

The arithmetic is the ruling's and it is not close. A 280 px name column beside a
48 px medallion, an 8 px gap either side, a 44 px Close and two 20 px insets needs
428 px at NARROW, where §1.2 gives the detail column 320. The previous code
recognised this and dropped the heading onto its own line below the medallion,
because a `Control` clamps its own size UP to `custom_minimum_size`: placing a
280-minimum Label in a 172 px slot silently widens it back to 280 and draws the name
straight through Close. The fix is not a smaller panel or a smaller font — the ruling
rules out enlarging the panel, shrinking fonts, ellipsizing and keeping the 280
minimum, in that order. It is `custom_minimum_size = Vector2.ZERO` on that instance
and an explicitly allocated rectangle.

`ui_resident_header.gd` therefore both publishes the table and derives it from the row
equation, and `is_consistent()` proves the two agree on every profile. A mistyped
table and a right formula is the failure mode that would otherwise show up as eight
pixels of overlap on one profile only.

## The `-0.00` that was nearly protected in the wrong place

The rate formatter rounds magnitude first with `(abs(R)+500)//1000` and applies the
sign afterwards. The first draft also guarded `signed_hundredths()` with
`if magnitude == 0: return 0`. **That guard was dead code**, and mutation testing is
what proved it: deleting it left the whole suite green, because integers have no
negative zero and `-0` is `0`. The real trap is one level up, in `text()`, which must
take its sign from the ROUNDED hundredths and never from the raw rate. Replacing
`if hundredths == 0` with `if rate_milli == 0` there does produce `-0.00 pp/h` for
R = -499, and does fail. The dead guard was removed and the live one is commented
with the reason, so the next reader does not restore the reassuring one.

## Center view is built, labelled and disabled

§4.1 requires the action; §4's catalog of 103 elements has no id for it; and
`ui_availability.gd` records REASON_NO_WORLD_CAMERA, "the interface binds no camera".
The previous position was to build nothing and report it. That no longer holds,
because UI-IDENTITY-R01 requires the 64 px footer and its 44 px button to stay
visible while the body scrolls, and requires Center view to be "its own labeled
action, not a click on the title".

So the button is built, named, given the store's actual reason as its accessible
description, and disabled. It carries no registry id, which keeps it out of
`_controls`, out of the focus chain and out of the hit table — the same treatment the
four extra UI-SET-039 instances already receive. **No camera binding is invented.**
That remains a reported gap, not a solved one.

## The medallion size changed at STANDARD

`emblem_pixels_for_width()` returned 48 for both 320 and 336 and 64 only at 384,
because the roundel then had to share a row with a 280 px heading. The ruling's table
publishes the medallion column directly and STANDARD now takes 64. One test assertion
was updated with that reason recorded in its own docstring.

## Two tests were inverted, deliberately

Both asserted that four of five need rows read `Rate unavailable`. That was correct
while `needs.gd` published one effective rate of five, and substituting the baseline
decay would have shown a resident asleep in a bed losing rest. NEED-RATE-R01 closed
that interface gap and says in terms to "remove it for successful reads after
implementation", so `test_the_four_unpublished_rates_say_so_rather_than_printing_zero`
and `test_the_four_rows_with_no_published_rate_say_so_on_screen` now assert the
opposite. `RATE_UNAVAILABLE` survives, reserved for a genuinely failed binding, with
its own test.

## What this decision does NOT claim

* **No visual approval.** ART-UI-12 is Brendan's and is recorded separately. The
  captures in [the evidence README](../validation/evidence/ui-refinement/README.md)
  are renders, not a verdict.
* **No screen-reader qualification.** Names, roles and descriptions are set and
  asserted. No assistive technology was run.
* **No age or life-stage in the identity column.** `residents.gd` gained a stage
  column under MOVE-DEP-R02, but nothing publishes a verified life stage into this
  heading, and the ruling forbids inventing one. Actual species and the published
  status are shown; the age statement stays in the supporting note.
* **The ref-first binding is not yet wired from the manager.** `fill_needs_for()`
  takes the selected `EntityRef` and is the entry point the ruling describes.
  `ui_manager.gd` still calls the slot-keyed `fill_needs()`, which resolves
  `ref_of(slot)` and goes through the same validated boundary — so no row escapes
  the directory check — but the selection's own reference is not what is handed in.
  `ui_manager.gd` is the integration lead's file and was left byte-untouched.
