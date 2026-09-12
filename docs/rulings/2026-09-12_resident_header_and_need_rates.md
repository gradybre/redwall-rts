# Astra — resident heading geometry and need-rate bindings

2026-09-12 · UI-IDENTITY-R01 and NEED-RATE-R01.
Specification handoff for UI-SET-037 and UXV-019/020; runtime implementation and
visual acceptance remain separate. Preserve the current executor worktree.

## UI-IDENTITY-R01 — a flexible name column beside the medallion

The280px minimum was written for a standalone title, not a name sharing a row
with a portrait and Close. It cannot apply to the resident-header instance under
SET-UX-VIS-002 §4.1. Override that instance explicitly; do not enlarge the detail
panel, shrink its fonts or stack the medallion above the name to retain280px.

Adopt this identity row in logical UI pixels, applying the existing scale S once:

`20 inset | medallion | 8 gap | name/species column | 8 gap | 44 Close | 20 inset`

| Profile | Panel width | Inner width | Medallion | Name column | Close |
| --- | ---: | ---: | ---: | ---: | ---: |
| NARROW | 320 | 280 | 48 | 172 | 44 |
| STANDARD | 336 | 296 | 64 | 172 | 44 |
| WIDE | 384 | 344 | 64 | 220 | 44 |

Panel widths/20px insets and the8px grid/44px target are inherited. Medallion sizes
and these explicit column bindings are new layout decisions. With a280px NAME
column the row would require388px Narrow or404px Standard/Wide inside available
280/296/344px: over by108/108/60px. The conflict is resolved by a flexible heading,
not by pretending the old minimum fits.

UI-SET-037 remains the semantic full-name heading. In this resident template its
intrinsic minimum width is0; allocate exactly the remaining172/172/220px under
these profiles. Do not set Label/container custom_minimum_size.x=280 or let a
long word's intrinsic width expand the parent. Other full-width037 uses retain
their own layout; this is not a global shrink of all titles or need rows.

Keep Noto Serif20px/600, full persisted name, wrapping whole words with a grapheme-
safe break for long unbroken names. Never ellipsize, reduce font size, split a
combining sequence, or cap the title at the old64px maximum height. Use the actual
font's measured line height. Place actual species and verified life-stage/status
beneath the name in the SAME column. Missing age/life-stage data is not permission
to invent a number, biography or stage; omit unsupported secondary data while
retaining actual species and the established unavailable-state behavior.

Medallion and Close align with the top of the identity block; the medallion stays
BESIDE the name in all three supported profiles. It remains a generic species
emblem unless an actual unique portrait is supplied and identified. Decoration
has no hit/focus/accessibility target. Close retains its44px hit rectangle at the
row's right edge. Center view remains its separately labeled action, not a click
on the title. Keep existing pin/rename actions in their owned action locations;
do not squeeze extra buttons into the172px name column.

Measure identity height as the maximum of medallion, complete name-plus-secondary
text block and Close, including declared internal text spacing. Then grow the
fixed header vertically and recompute body height. Preserve the64px action footer
and its44px Center view button; only the content body scrolls. Do not move Close
below the need list or let header growth overlay health/needs. Fit must be checked
at the minimum logical viewport; fixed header/footer may not consume the whole
body. No stacked fallback is adopted for the current profiles. A future expanded
accessibility/localization mode needs its own evidenced geometry rather than a
silent change to this composition.

Main-tree audit found the older generic vertical flow with12px padding and Close
at its bottom, without a medallion composition. The executor's reported stacked
medallion may be newer worktree code; this ruling applies to it too. Do not treat
that code difference as a reason to discard concurrent work. Implement a dedicated
resident header/body/footer rather than extending the generic list minimums.

Acceptance: exact columns above; short and32-character names, including a long
unbroken name and combining characters;100/125/150% scale and live profile
transitions;20/600 preserved; no overlap/horizontal clipping; medallion beside
name; top-right Close stays operable; body scroll and footer remain reachable;
heading semantics and focus order survive resize. Capture actual Mac renders,
including1280×720@150%, for visual review. Arithmetic fit is not a screenshot pass.

## NEED-RATE-R01 — expose the same continuous rates the integrator selects

The four missing public readers are an interface gap. Current needs.gd already
selects their rates in `_fill_need_rates`; UI must not recreate those formulas,
read private columns or substitute a universal baseline for missing data.
Needs owner adds these non-allocating public methods, using the existing
caller-owned IntMath.IntResult contract:

```gdscript
func rest_rate_milli_per_hour_into(slot: int, out: IntMath.IntResult) -> bool:
func comfort_rate_milli_per_hour_into(slot: int, out: IntMath.IntResult) -> bool:
func social_rate_milli_per_hour_into(slot: int, out: IntMath.IntResult) -> bool:
func purpose_rate_milli_per_hour_into(slot: int, out: IntMath.IntResult) -> bool:
```

These are API signatures to implement, not executable bodies. Each validates a
present, living resident typed row using the existing guards. On failure return
false with out.ok=false, the actual refusal and a cleared value; caller MUST NOT
interpret that zero as a valid zero rate. On success return true/out.ok=true and
the signed NET rate R in milli-need-points per SIMULATED hour. Zero is a legitimate
success for a balanced condition, notably mild-outdoor comfort.

The existing hunger_rate_milli_per_hour(size_class) remains a POSITIVE decay
magnitude with current size/season applied. Do not change its established sign
or callers; the selected-resident adapter obtains the verified resident size,
checks the result, and uses `R=-magnitude`. The four new readers are signed net
rates already: do not negate them again or subtract baseline a second time.

Use the existing selector/helper logic as the single rate authority. A cold-path
reader may validate the slot, invoke `_fill_need_rates(slot)`, then copy its named
scratch entry into out. An equivalent shared-selector implementation is acceptable
if independently verified. Reusing bounded scratch is allowed; it is not a cached
rate or new authoritative field. Read only between completed simulation updates,
not reentrantly while integration uses that scratch. Never return a shared scratch
reference to UI or mutate needs, integrator remainders, activity/environment flags,
status, clocks or RNG. No event is applied by asking for a rate.

Keep `_fill_need_rates` as the simulation's one-pass path. Do not replace it with
five allocating/public-reader calls per resident per tick, or add a per-resident
rate cache/dirty flag. UI requests rates only for its selected-resident snapshot,
with caller-owned reusable results. Existing arithmetic/sign/remainder behavior
must remain unchanged. A valid current model default is the rate the simulation
actually uses, not permission to claim a bed, heated room or pairing exists when
its producer is absent. Report source-wiring limitations separately; reader
availability alone does not certify those environmental systems.

### Exact inherited rate fixtures (at interior need values)

| Need/context | R milli-need-points/hour | Display pp/h |
| --- | ---: | ---: |
| Hunger Small, nonwinter | -250000 | -2.50 |
| Hunger Medium, nonwinter | -300000 | -3.00 |
| Hunger Large, nonwinter | -400000 | -4.00 |
| Hunger Small, winter | -300000 | -3.00 |
| Hunger Medium, winter | -360000 | -3.60 |
| Hunger Large, winter | -480000 | -4.80 |
| Rest awake | -375000 | -3.75 |
| Rest sleeping in bed | 1200000 | +12.00 |
| Rest sleeping on floor | 750000 | +7.50 |
| Comfort no restoration | -100000 | -1.00 |
| Comfort valid heated room | 200000 | +2.00 |
| Comfort mild outdoors | 0 | 0.00 |
| Social unpaired | -100000 | -1.00 |
| Social paired | 1100000 | +11.00 |
| Purpose no restoration | -75000 | -0.75 |
| Purpose useful labor | 245000 | +2.45 |
| Purpose mentoring | 325000 | +3.25 |

Comfort/social/purpose are restoration MINUS decay; sleep has NO awake decay.
A shared meal's social+200 and food/NP intake are discrete events, not an hourly
rate; do not divide them by a guessed frequency or include future planned jobs.
These values are inherited from GDD §5.2 and current selectors, not new balance.

### Display meaning, caps, pause and formatting

UXV-020's hourly number now explicitly means **continuous rate produced by the
current model conditions, before need-value clamping**. It is not the last tick's
rounded value difference or a forecast that those conditions will persist for a
whole hour. Never estimate it by temporarily advancing the resident750ticks.

At need0 with negative R, or need10000 with positive R, KEEP R and mark **Capped**.
The explanation says further outward change is discarded at the bound; inward
rates remain uncapped. Do not report0 merely because the current value is capped,
and do not imply the displayed need will exceed0–100%. A capped Hunger row does
not imply starvation health damage has stopped; health retains its own owner.
Pause and speeds0/1/2/4 do not scale these per-simulated-hour rates. While paused,
no simulated hour elapses; keep the rate and existing pause indication visible.

Need value remains `value/100` percent; rate is `R/100000` percentage points/hour,
displayed with two decimals and `pp/h` (full accessible words: percentage points
per simulated hour). Use existing nearest/ties-away-from-zero presentation rule.
An integer formatter can round magnitude to hundredths with
`(abs(R)+500)//1000` over the validated rate domain, then apply sign and decimal
placement; normalize a rounded zero to0.00, never-0.00. This is display arithmetic,
not an authoritative integrator change. Use raw sign and Capped status for the
trend explanation; never feed formatted numbers back into simulation.

The snapshot owner first validates the selected EntityRef/generation through the
directory and resolves its RESIDENT typed row, then copies values and rates at
one completed-state boundary. A global entity slot, persistent ID or cached stale
typed row is not interchangeable. A dead/retired/stale resident has no live rate;
follow the existing death/selection transition or show the actual unavailable
reason, rather than querying a replacement row. All five rows use the same
snapshot identity. Retain Rate unavailable on true failed/missing bindings only;
remove it for successful reads after implementation. Do not mark UXV-020 passed
while any otherwise supported row still lacks its published rate.

### Implementation ownership and required evidence

Needs coder owns needs.gd and focused test_needs.gd changes. UI/snapshot coder
owns selected-resident bindings and formatting; integration lead coordinates
shared snapshot/manager changes. Independent review checks no extra hot-path
calls/allocations and no duplicate formula in UI. No new packed column, schema
version or simulation-memory allocation is required by these read-only methods.
Any added presentation snapshot storage remains measured transient data.

Pin every rate row independently, then compare against750 actual need ticks
from an interior value such as5000 with unchanged context and known remainder.
For signed R the expected uncapped delta is
`trunc((initial_remainder+750*R)/750000)`, with retained signed remainder checked.
Also test nonzero initial remainders and direction changes. Do not compare only
two functions sharing the same mistaken expression.

Test awake/bed/floor, none/heated/mild comfort, paired/unpaired, none/labor/mentoring,
size+season hunger, immediate context changes with no cached lag, valid zero,
invalid/free/dead rows, stale selection/slot reuse, repeated reads leaving all
state bytes unchanged, and both outward/inward behavior at0/10000. Test paused
and1/2/4 speed snapshots: displayed rates agree at equal model conditions.
Formatter fixtures include R=250000→+2.50,245000→+2.45,±250500→±2.51,
±499→0.00 and±500→±0.01. Meals remain events. Actual UI capture must show five
successful rate bindings and appropriate cap/paused states without overflowing
the52px need row; full unit/cap explanation remains accessible.

## Claude execution order

1. Needs coder adds the four public readers and meaningful focused fixtures.
2. UI owner builds the fixed resident identity header with the table above and
   binds all five rate rows from one validated snapshot. These lanes can proceed
   in parallel with disjoint files; coordinate the snapshot interface first.
3. Run applicable tests, then capture all profiles/scale cases and report actual
   results. A correct contract or headless test is not visual acceptance.

No runtime code, assets or commits are produced by this ruling. Source/geometry/
arithmetic checks are recorded in [validation](2026-09-12_resident_ui_validation.json).
