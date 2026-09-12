# Astra follow-up — alert profiles and expired-seed yield

2026-09-12 · ALERT-R02 and STOCK-SEED-R01. These are specification decisions,
not claims that notification details or live starter-seed aging are implemented.

## ALERT-R02 — full text is preferred on STANDARD/WIDE

The intent was NOT to force compact summaries on every profile. NARROW always
uses the authored compact summary. STANDARD/WIDE prefer the complete original
notice when it fits, with summary fallback under explicit layout rules.
This clarifies [the prior alert ruling](2026-09-11_initial_ids_and_narrow_alerts.md)
and UI §1.2/§8.2; it preserves the existing alert-zone bounds and priority order.

Use a notice model with separate `summary` and `full_message`, plus severity,
source/code, actual recovery action when available and stable notice identity.
Do not overwrite full_message with summary at the producer or pass one undifferentiated
string through all profiles. A naturally short complete message may equal its
summary; an arbitrary long clock diagnostic cannot be treated as authored compact
copy. Preserve full accessible text and details for every live notice.

NARROW: one44px card in the48px zone, showing an authored summary that fits at
the selected font/UI scale. Never ellipsize, crop text or shrink the font to force
fit. Supply shorter authored summary variants where required by measurement.

STANDARD/WIDE:96px outer zone,2px inset top/bottom,92px content height,4px between
cards, minimum card height44px. Insets/gap/card sizes are inherited from UI §1.2; the adaptive packing is newly
made explicit here. Measure full-message
height at the actual profile width, font and scale, including padding and any
count/action affordance. Never let independently growing cards overlap.

1. Measure the highest-priority notice. If its full card is at most92px, use
   full text; otherwise use its44px authored summary.
2. If a second notice exists, use its full card if it fits the remaining content
   height after the4px gap. Otherwise use its44px summary if that fits. Otherwise
   show only the first card. At most two cards, preserving established priority.
3. Expose the number of undisplayed notices through the existing notice/detail
   affordance in the existing36px history rail, with its32px trigger; do not add
   an unbudgeted third row or cover message text.
   Measure with that affordance present so it cannot overlap message text.
4. Place card2 at `card1_bottom+4`, not at a fixed origin48px below card1's top.
   Recompute after profile/width/scale/content changes without moving keyboard
   focus to a different notice or deleting full content.

Consequences: two44px full cards fit exactly92px. A44px first full card plus
an oversized second gets a44px second summary. A60px first full card appears
alone. A first notice too large for92px uses a summary; another card may then fit.
This is adaptive packing, not always-compact STANDARD/WIDE.

Activate any card with pointer/Enter/Space to open its complete wrapped,
scrollable message, source/code and real recovery action, with focus return to
the invoking notice/control. Accessible description includes severity and full
message. Tooltips alone are not the detail path. Where notification history is
not implemented, supply selected-live-notice details without claiming a complete
history system; do not leave the only route to full content disabled. Use the
owning bounded notification/history contracts, never an unbounded new log.
Critical integrity failures retain their existing blocking modal behavior.

Current main-tree audit: callers/HUD forward one string across profiles; the shell
shows it as text/tooltip/accessibility content, history availability is false,
and layout lets independently positioned STANDARD/WIDE cards grow. Therefore
neither a full two-card adaptive layout nor the required detail path is verified.

UI owner implements the notice model, producers/HUD/shell/layout and details;
independent UX QA captures all three profiles at100/125/150% scale. Test the four
packing examples, profile-dependent wrapping, authored-summary fit, preserved
full text, no out-of-zone rectangles, no world-click leakage, keyboard activation
and focus restoration. Screenshots and user review still determine visual quality.

## STOCK-SEED-R01 — expired seed converts by exact nominal mass

GDD §5.8's seed→compost arrow now has an explicit automatic-expiry yield:

```
compost_quantity_milli = floor_div(
    checked_mul(seed_quantity_milli, seed_item.mass_g_per_U),
    compost_item.mass_g_per_U)
```

Exactly one final floor; positive validated catalog masses. All five current seed
items use100g/U and compost1000g/U, so this is `floor(seed_quantity_milli/10)`.
This is a NEW explicit expiry-conversion rule, not a copied composter recipe or
a claim that all game recipes conserve physical mass. Item masses are inherited.
Never calculate from the container's ceil-rounded capacity charge: that could
create compost through lot fragmentation.

| Expired seed milli-U | Compost milli-U | Nominal conversion remainder |
| ---: | ---: | ---: |
| 1 | 0 | 0.1g decay loss |
| 9 | 0 | 0.9g decay loss |
| 10 | 1 | 0g |
| 19 | 1 | 0.9g decay loss |
| 1000 | 100 | 0g |
| 10000 | 1000 | 0g |

Apply per expiring lot under the existing deterministic expiry order, with no
cross-lot remainder carry or new remainder arena. The sub-output-unit remainder
is deliberately discarded as decay. Splitting a lot cannot increase compost:
`sum(floor(q_i/10)) <= floor(sum(q_i)/10)`. Do not silently merge unrelated lots
or cross containers to recover rounding remainder.

Trigger only when the existing hourly aging pass reaches the seed lot's declared
expiry (`age_milli_hours >= catalog_shelf_hours*1000`) and the owning item has
its seed flag. Retain the existing seed shelf life and storage-class aging rules;
all five baseline seed items have1440-hour shelf life. Storage/temperature
factors already change hourly aging; do not apply them again to shelf_hours. No conversion on sowing,
seed separation/transfer, cancellation, crop withering, reads or composter work.
Do not change food-spoilage yields by generalizing this one rule.

At the expiry mutation boundary, Inventory atomically invalidates/releases the
lot's reservations, records the ENTIRE seed quantity as a seed sink and the
calculated positive compost quantity as a compost source, and transforms the
existing lot under its ordinary transformation API, resetting age. Existing
quality/location/ownership rules of that API remain in force; no extra loot or
quality roll. When output is zero, atomically invalidate reservations and sink
retire the seed lot without creating a zero-quantity compost lot. Job/intent
invalidation follows existing expiry ownership; no worker keeps a valid claim to
seed that became compost.

Checked arithmetic or transaction failure leaves the expiry transaction's input
snapshot unchanged, with explicit failure/retry behavior. The earlier hourly age
advance is not retroactively undone by that promise; compare the correct boundary.
Failure containment is explicit: every seed-consuming eligibility path (new
reservation, withdrawal, transfer into production, seed selection and sowing/work
commit, including existing reservations) MUST reject a seed lot whose existing
age has reached its catalog shelf threshold. Revalidate at commit. This predicate
is derived from persisted age/item definition, requires no new per-lot flag or
remainder store, and is active before resuming consumers after the expiry pass.
Inventory owns enforcement for quantity admission, with the verified immutable
item definitions; StockAge owns transformation. Release/cancellation and declared
expiry transform/sink operations remain permitted, so the guard cannot prevent
its own cleanup. Render totals may show unusable expired stock distinctly but
must not count it as usable seed supply.

Arithmetic, ledger or schema failure is a blocking integrity fault through the
existing critical-pause path, not a nonfatal warning followed by periodic aging
retries. The eligibility guard prevents use even before that pause barrier is
applied. Keep the aged lot and ledgers unchanged at the failed conversion
boundary. Resume only after verified recovery or an explicitly revalidated retry
of that SAME expiry transaction; retry adds no age, does not rerun completed
hourly work and may not duplicate sinks/sources. Never clear the pause while the
failure remains unresolved. An unsafe partial world uses the existing recovery
path, not a fabricated successful tick. Do not saturate overflow or make expired
seed usable by rewinding its age.
No extra container capacity may be charged from rounded seed mass. Required
nominal invariant: `compost_milli*compost_mass <= seed_milli*seed_mass`.
Per-item source/sink ledgers record the transformation, not equality of unlike
item units. A separate authoritative mass-remainder field is not introduced.

Catalog owner owns item flags/masses/shelf life; StockAge owns trigger and yield;
Inventory owns mutation/reservations/ledgers; SettlementSystem owns hourly dispatch;
storage owners supply actual storage class. Implement the missing seed branch in
StockAge rather than a background special-case loop. The current starter economy
and canonical aging inventory still need their real integration; this ruling
does not assert that starter seeds now age.

Acceptance: all five seed types, listed boundaries, shelf-hour exact crossing,
reserved seed conversion/cancellation, zero output retirement, checked overflow,
transaction refusal at the expiry boundary, immediate rejection by ALL seed
consumers including preexisting claims, critical-pause/recovery and exactly-once
retry/save continuation, split/unsplit no-gain inequality,
ledger totals, no conversion on reads/transfers and no change to ordinary food or
composter recipes. Continue through the real hourly caller and save/reload once
those production owners exist; a direct StockAge unit test is not full integration.
