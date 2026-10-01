# 0438 — The regatta feast: a once-a-season occasion, a deterministic race, and the GDD's Hearth feast as written
Date: 2026-10-01 · Status: Accepted (the feast's missing courses: for Brendan's ruling, see below)

Water part B, lane 3 (group K of decision 0493: "the regatta feast"). Review SOC-023 (feasts with an occasion and
memory), SOC-025 (traditions: a graceful skip, no exclusive power item), UX-028 (feast dressing driven by real food).
SOC-024 (several feast forms, which would change the GDD's bundles and 80 % rule) is NOT adopted: Brendan did not
change the GDD's feast rules, so they are used as written.

## Decision

**The occasion** (`demo/regatta/regatta.gd`, numbers in `regatta_rules.gd`): once a season, **the first in the first
summer**. The player picks the **day** (that season's days from tomorrow; in spring, the coming summer's) and the
**host** (any resident but the village cook, who cooks it), and sees the **preview** before holding it. Held or skipped,
the season is done -- no second regatta, no re-roll of the day (anti-farming). **Skip** costs nothing and withholds
nothing: a held plan's food and wood go back untouched; there is no item, title or bonus that skipping loses.

**The race** (presentation of a deterministic result): the boathouse's two rowboats, each crewed by a helm (FISH >= 1)
and a second -- the two best helms and the two best others, never the host or the cook. Crews are called to the
boathouse jetty at **13:00** (work parked, as a meal call parks it), board, and at **15:00** both boats push off down
equal straight lanes (**6.0 m** out to a floating barrel and back). Each rows at `1000 + 40 × (helm FISH + second FISH)`
per mille of the boat core's speed (DEMO), so the better-fishing crew is home first, the same every time; equal paces
are a dead heat. A storm (REQ-SET-052), ice, or a crew not aboard by **16:00** calls the race off; the feast still is.
A crew still walking when it is called off is done on arrival -- it never takes a boat for a race that is off -- and
any rowboat the race holds goes back to the boathouse, at its ordinary pace, as soon as it is moored.
No wager, no prize: the winners are honoured in the chronicle (a dead heat names both crews there; no deed, as no
crew won).

**The feast -- the GDD's Hearth theme, as written** (§5.7, REQ-SET-100..106), for E = every living resident:
main course ceil(E/3) batches of `bean_hotpot` (beans 2, cabbage 2, water 2 -> 3 × 2100 NP, 20 WU, 36 h -- added to the
kitchen as its fourth dish, cooked only for an occasion), second course ceil(E/3) `nut_loaf`, warm infusion (water
ceil(E/4) U, herb 0.25 × ceil(E/12) U); staffing 2 cooks + 1 keeper (the village cook, a helper, the host; the demo has
no cooking skill to check the GDD's skill 2 against); seats >= ceil(E/3) (the hall seats 10); service wood ceil(E/12) U
**set aside at confirmation**; REQ-SET-101's **3 food-days and 3 fuel-days** after it, or the player's explicit
**override** for this regatta; REQ-SET-104's **80 %** of E at every required course for the buff. For the demo's nine:
3 hotpot batches (6 U beans, 6 U cabbage, 6 U water), 3 seats, 1 U service wood.

**The demo's missing courses -- the reading recorded for Brendan's ruling**: the village has **no nuts and no herb** (no
source of either exists; the content groups that add forage are queued), so `nut_loaf` and the infusion **cannot be
made**. Refusing the whole feast under REQ-SET-099 would make the regatta feast impossible in the demo; substituting
other dishes would be SOC-024's change to the GDD's bundles. This lane takes the third way: the preview **declares**
the two courses unservable ("can't be made — the village has no nuts or herb"), the feast serves the main course it
can, and REQ-SET-104's "otherwise" branch applies -- **no Shared Warmth**, the attendees' meal and their company only.
If Brendan rules otherwise (refuse such a feast; or add nuts and herb to the pantry first), the change is confined to
`regatta.gd _feast_refusal` and the preview's words.

**The day's supper is the feast**: on holding it, the main course's beans and cabbage are **reserved at once** in their
own take, which the kitchen then cooks from (`kitchen.gd AN OCCASION`: `set_occasion` / `clear_occasion`; never chosen by
the everyday alternation); the kitchen cooks exactly the feast's batches and serves them at its **17:00** supper call to
everyone called as ever -- the GDD's 18:00 start would run its waves into the demo's 20:00 night (decision 0421), and the
hall's ten seats need one wave. Portions are consumed only on eating (REQ-SET-103, the kitchen's own rule); surplus
portions are ordinary food. The supper song is the songs' own (sung at the supper table: nothing in the songs changed);
the race's otter crews sing their work songs while they row -- the songs read the race's rowing as work through one
added hook (`demo_songs.gd add_work_reader`, the regatta's `rowing`), since a race crew is on no work board. Residents
gather at the hall's tables.

**Remembered** (SOC-023): at the supper's end the tally (who ate the main course), then the **chronicle** -- a Village
news line (the history's Village source): the day, the host, the race, how many shared the feast, and **one moment**
(the race's finish; with no race, the supper song) -- and, through the people's ledger hooks, the winners' deed: one
new kind, **`KIND_REGATTA`** ("Won the summer regatta's race"; trivially adopted: a kind, its words and its reflection
rank), **pinned to the chronicle**; and REQ-SET-036's **+5 affinity** for every pair who shared the feast
(`people_ledger.gd add_feast`, FEAST_GAIN -- the GDD's number the ledger had noted it had no feast to apply to).

**The surfaces**: the Water panel's Regatta section (◀ Day / Day ▶, Host ▸, Hold the regatta, Override reserves, Skip this
season -- each with its action card from the same decision); the HUD's **Feast** command (UI-SET-032), unlocked by the
demo to bring that section forward; the field guide's "The regatta" and "Bean hotpot" entries and one help topic
"Ferry and regatta" (no new objective).

## Why

The approval was for "the regatta feast" (group K). SOC-023 gives the occasion its structure; the GDD gives the feast its
numbers. The demo's pantry cannot make the Hearth theme's second course or infusion, and saying so in the preview -- then
granting exactly what REQ-SET-104 grants when not every course is attended -- keeps every GDD number and rule while
letting the occasion happen. The race is deterministic from the crews' own skill so it is honest presentation, never a
gamble.

## Consequences

- The kitchen has four dishes; the fourth only ever cooks for an occasion.
- The people's ledger has nine kinds; its affinity now applies the feast's +5.
- A regatta needs two helms; with fewer the preview refuses it ("a fisher learns on a net from the bank").

## Source

GDD §5.7 feast table and rules, REQ-SET-036, REQ-SET-052, REQ-SET-099..106; review SOC-023, SOC-024 (not adopted),
SOC-025, UX-028; decision 0421 (the demo's day); decision 0442 (the songs); Brendan's approval (decision 0493, group K;
decision 0439).
