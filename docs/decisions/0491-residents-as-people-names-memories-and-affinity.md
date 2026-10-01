# 0491 — Residents as people: the demo cast's names, committed memories, light relationships and lines
Date: 2026-10-01 · Status: Accepted

Numbered 0491: review group T was given 0491–0499; none of them was taken on any branch or worktree (the highest
nearby were 0451, 0461 and 0471).

## Brendan's rulings (2026-10-01)

- **The demo cast is an ORIGINAL community.** Rowan stays the settlement game's Warden (LORE-U28); the mouse keeper is
  not Rowan, and no literary character or era is implied (P6's "do not silently equate 'Mouse keeper' with Rowan").
- **Names, all option A, each with a personal interest and a way of speaking:**

| Cast key | Name | Interest | Speech |
|---|---|---|---|
| `mouse_keeper` | Wenna Tallowby | carves tiny animal figures for the windowsills | plain, unhurried |
| `mouse_fieldworker` | Jory Whitethorn | can whistle a dozen birdcalls | short, cheerful |
| `squirrel_gatherer` | Linnet Whinberry | plays a reed pipe, badly and often | plain |
| `squirrel_forester` | Tobit Highbough | sorts a pebble collection by colour | slow and careful |
| `otter_boatwright` | Tegwin Slipstone | is teaching himself to read from an old almanac | plain |
| `otter_fisher` | Corra Netley | sings rounds and teaches them to anyone nearby | calls everyone "friend" (her habit, not an otter's) |
| `mole_digger` | Tuppen Clayholm | keeps a box of odd keys and buttons | light molespeak: "hurr", "burr aye", one a line at most (DEC-017) |
| `badger_quarryman` | Hulda Slatebrook | embroiders samplers with old sayings | soft-spoken |
| `beaver_bridgewright` | Elstan Weirholt | plays the fiddle in the evenings | plain |

- **Hand-written for the demo cast only.** The main game's fixed 32-entry given-name and surname catalogs and its
  naming algorithm (`docs/game_gdd.md` §5.3, lines 370–372; RWL-NAME-1) are unchanged; per `setting_bible.md` §13.2
  changing them needs a versioned amendment, which this is not.
- **Trades stay roles**: "Wenna Tallowby — mouse, keeper"; "Wenna Tallowby (mouse keeper)" where the role helps.

## Decision

1. **One data file.** `godot/demo/people/demo_people.json` holds each cast key's name, interest, speech, evening
   pastime, pleased line and dialect words, with its provenance: ORIGINAL, written for the demo, not from the books
   (`setting_bible.md` §3.2: original design is labelled original). `people_book.gd` reads it once; a key without a row
   (a placeholder) keeps its key's label. `demo_actor.gd display_name` is the person's name, so every surface that
   named "Mouse keeper" -- the roster, the party panel, the Work screen, the news, incidents, action cards, refusals, the
   bridge crew's feed, the kitchen's lines, fed lines -- now names Wenna Tallowby with no surface keeping its own copy.
   Where the role helps choosing it is written with the name: the roster ("— mouse, keeper", species lower case for every
   row), the party panel's species line ("Mouse, keeper") and the Work screen's resident rows ("Wenna Tallowby (mouse
   keeper) — Haulers crew"; `work_board.gd label_of`). A keyed placeholder body keeps its key's species.
2. **Memories are committed deeds only** (`people_ledger.gd`, written by `people_taps.gd`). The taps read each owner's
   state for the EDGE where it has committed a deed, as the sound's event map does (0351), and write structured rows --
   kind, deed, who, the other person, the place (a news "Go to" target), the tick, an amount, the subject's name at
   commit; words are made when read. The bounded event types:
   - **rescue** -- a victim a rescuer brought ashore (`rescue.gd`'s new ASSISTANCE LOG, written in `ashore` with the
     victim task's responder): the rescuer's "Brought X ashore" and the victim's "Brought ashore by Y", one deed. A
     victim the water washed ashore (the safety net) is no assistance and logs nothing;
   - **bridge** -- a bridge row going PLANNED -> OPEN in the same generation: everyone seen as its builder while
     loading, carrying or building it. A row whose generation moves on (another bridge in it) forgets its builders. A
     planned bridge cannot be cancelled in the demo (`bridge_work.gd` NO_CANCEL), so there is no cancelled bridge to
     test; the edge alone keeps an unfinished one out;
   - **tunnel / room** -- a live piece of the network becoming done: each lead whose segment was cut while it led and
     each crew member at its post while a cut was made. A dig called away part done is PAUSED, not done: no memory; a
     piece dropped unbroken: none;
   - **first harvest** -- `farm_crew.gd`'s new HARVEST LOG, written when a HARVEST job's last load is stored; a harvest
     cancelled after it was cut is carried in as its delivery (0222) and logged as no harvest;
   - **skill level** -- each level a watched skill's XP crosses (felling, sawing, digging, bridging; §5.3's curve). The
     levels at boot are the baseline: a starting level is no deed;
   - **meal for everyone** -- a meal whose serving ended with nobody gone without: each cook of its batches
     (`kitchen.gd`'s new `cooked_by` column), at the cook's FIRST such meal only (twice a day would drown the rest).
3. **Curation and notability.** The resident's history lists its moments newest first; the player can pin a deed to the
   chronicle, keep it private, or dismiss it (it leaves that history; the fact stays). `pin_notable` marks a resident
   notable (REQ-SET-042); it changes no skill, need, labour or consumption -- the roster shows ★.
4. **The spotlight (SOC-001).** After a distinctive deed -- a rescue, a bridge, a tunnel or a room -- each participant
   not yet notable is offered ONE spotlight per deed kind: "Corra Netley brought Tuppen Clayholm ashore. Spotlight Corra
   Netley as one of the village's notable residents? It changes nothing about the work". At most four wait.
5. **The season's reflection (SOC-028).** At a season's end up to three of its uncurated deeds are offered, ranked
   rescue, a build, a first harvest, a meal, a skill, earliest first (the rescued side is never offered: its rescuer's
   deed is). Pin to chronicle posts "Chronicle: <deed> (Spring 4)" to the village news (I's history, 0331), about the
   resident; Keep private and Dismiss post nothing; Later leaves them uncurated. Only committed deeds exist to offer.
6. **Affinity (SOC-014): the GDD's adopted numbers, used minimally, with one ADAPTATION.** `docs/game_gdd.md`
   REQ-SET-035..037 and §5.3 (lines 353–368). REQ-SET-035's +2 is for 60 WU of SOCIAL activity, which the demo does
   not have; the demo applies the same +2 to the everyday contacts it does have -- an hour (60 WU) worked side by side
   (two of the same crew on work-board tasks within 8 m of each other, or the lead and crew at the same dig), or a
   supper eaten together -- at most once a pair a day. That mapping is this decision's, not the GDD's. A rescue adds 8,
   once per rescue (REQ-SET-036);
   friends from 40, cleared below 25; -100..100; three days without contact, one point a midnight toward 0. Mentoring,
   the GDD's only friendship effect, is not built in the demo, so **affinity has no mechanical effect**. The cast starts
   with no relationship (the GDD's starting edges belong to its own twelve). The degree cap of 8 cannot bind nine.
   Shown lightly, at most three lines: "Rescued by Corra Netley", "Friends with …", "Often works with …" (3 shared
   hours), "Often at supper with …" (3 suppers).
7. **The inspector (P6)** is the party panel's one-resident view: the name and its role, what it is doing and WHY (the
   kitchen's part, the night, the water's hold, an emergency, its crew's own work or a hand lent, an order, or free),
   how fed it is, and its skills as "Felling · Level 3" over a meter of progress to the next level (the skill-only text
   providers step aside for one resident). "About Tobit ▸" opens, only when asked, the interest, the evening line while
   true, the relationships, the notable pin and the notable moments, each with Go to (its place) and the other person.
   Learned skill stays apart from the body's clearance and orders (the abilities lines).
8. **Light, truthful lines.** At most ONE evening line a day, at 19:00 (supper over, dusk not come): the next resident
   in turn who is actually free on the surface then, doing its own pastime where it is ("Wenna Tallowby is carving a
   tiny animal figure for a windowsill at the hall table"), with its own pleased line only after a deed of its own
   committed that day. It is a NOTE in the news, never a warning, a sound or a card.
9. **Dialect only in Tuppen's own lines (DEC-017).** The old Foremole lines were heavy molespeak said by whoever led
   the dig -- a mouse or the badger too -- and the rock warning, functional text, was dialect. They are now plain
   SAYINGS spoken under the actual lead's name (`tunnel_works.gd speak`, through `demo_people.gd voice`), with one of
   the speaker's own dialect words only when its data row has any (only Tuppen's does); the rock warning is plain:
   "The dig has reached rock: it goes slowly without a badger on the crew to break it". Roster rows, the inspector,
   why lines, spotlights and every functional string stay plain.

## Why

- **Edges in committed state, not hooks or prose.** Reading each owner's state where it has committed (the sound's
  approach) keeps the owners' code untouched except three small logs where the actor is gone by the time the state
  shows it (a rescue's rescuer, a harvest's worker, a batch's cook). Parsing the news' words was rejected: prose is
  presentation, and a cancelled job can still have been said.
- **A first harvest, a first meal for everyone**, not every one: twice-daily meals and every harvest would bury the
  rescues and bridges a player wants to find. Every skill level is kept (they are rare: level 4 is 80 000 XP).
- **The GDD's affinity numbers** (P6: relationships are adopted) rather than new ones; with no mentoring built, any
  effect would have been an invented bonus, which the brief and P6 forbid.

## Consequences

- A new kind of deed is a new KIND_* in `people_ledger.gd`, its words in `people_text.gd`, and a tap on its owner's
  committed state -- never a call from the owner's code into the people.
- The demo cannot save, so names, memories, curation, notability and affinity last a session (the review's "across
  reload" waits for the save work).
- The ledger keeps 512 events and 1024 deeds; the oldest go first. Which "firsts" a resident has had is a bit
  column of its own (`firsts`), so a first harvest pushed out of the events is never recorded again (the review's H2).
- The taps count a segment's cuts only when its dig progress or phase moved (the review's H1: re-reading every open
  segment's timeline cost about 0.35 ms a frame with twelve tunnels; about 7 µs with the gate).
- The offer card is a fifth F7 region, after the Map layer picker, while it shows.
- **Open:** "first excellent craft" (SOC-001) has no craft quality in the demo; a Chronicle view of its own (the pinned
  deeds are kept in the ledger and posted to the news history); naming a crossing or a hall panel after a pinned moment
  (SOC-028's extensions); Corra teaching a round to whoever is actually near her; family-stage presentation (PC-04).

## Verification

- Suites, no staged assets: `test_demo_people.gd` (the data file, the ledger, curation, affinity, and the taps on the
  real rescue, bridge build, tunnel network, farm harvest and kitchen meals: a cancelled harvest, a paused dig, a
  washed-ashore victim and a row's new bridge leave no memory) and `test_demo_people_ui.gd` (the same person on the
  roster, the panel, the Work screen and the news; the inspector's meters, About, moments and Go to; the spotlight, the
  reflection and its chronicle line; the evening lines; dialect only in Tuppen's own lines, never in functional text).
  Updated: `test_demo_hud_truth.gd` (the roster's species is lower case).
- `./tools/run_tests.sh`: **"7149 test(s), 563182 assertion(s), 0 failure(s)"** (base c228d90: 7082).
- The live harnesses: `demo_input_live.gd` LIVE-SUMMARY 182 0 (1280x720) and 190 0 (1920x1080); `demo_layout_live.gd`
  145 0 and 211 0 (a timing-dependent branch makes the count vary by two run to run: 143/209 in other runs, and the
  base commit c228d90 with the same staged assets gives 145 and 209); the new `demo_people_live.gd` (real clicks on
  the roster, About, a moment and the spotlight; its runner `test_demo_people_live.gd`) 32 0 at both, staged, and
  28 0 with nothing staged. Frames: `scratchpad/rv_t_check/{roster,inspector,notable_event,spotlight}_{1280x720,
  1920x1080}.png`.
- **Mutation testing**, one mutant at a time in an unstaged copy, each file restored and its SHA-256 checked: **128
  distinct mutants** over three rounds (84 of the people's logic, 16 more from the review's list, 28 of the owner
  edits). First round 61 of 84 killed; each survivor got a test, and the rounds after killed all but two: **126
  killed, 1 equivalent** (a victim washed ashore through `ashore` instead of `_land`: the safety net's stand-down has
  already released the responder) **and 1 retired** (`is_free`'s order clause, implied by `ACTIVITY_WANDERING`, removed).

## The review (code-reviewer, 2026-10-01), fixed

- **H1** the taps re-read every open segment's whole timeline each frame (0.35 ms with twelve tunnels): cuts are now
  read only when a segment's progress or phase moved, and a new segment in a slot starts from none.
- **H2** a "first" deed was recorded again once its event aged out of the ledger: `firsts`, a bit column per resident.
- **M1** the untested lines it listed (a piece's new generation, the cut check, the crew at its post, rooms, the 40/25
  gap, the notable offer, the bridging meter's wiring, the dig lead as speaker, `is_free`, the kitchen's and an
  emergency's why, a forgotten deed's events, `meal_ate`, the shared ticks, the two-word tag) each have a test.
- **M2/M3** the bridge test that could not fail now builds the stale-hands case honestly; tests that restated their
  own code or read literals were rewritten or dropped; the live harness's names check holds staged or not.
- **M4** "together" means side by side: the same crew within 8 m on work-board tasks, or the same dig (a board row has
  one worker, so the old "same task" clause was dead); this decision says the +2 for it is an adaptation.
- **LOW fixed**: no list made per event dropped, `SHARED_HOUR_TICKS` from SimClock, typed skill sources, several
  midnights in one look each decay, the card's null checks. **Left**: six test methods over 30 lines; `demo_village.gd
  _ready` is 33 lines (32 before); an offer pushed out by the four-offer cap is not offered again; an evening whose 19:00
  is skipped by the Lab's weather skip has no line; a few helpers only tests call (`name_with_role`, `has_person`,
  `record`, `chronicle_into`).

## Source

Brendan's rulings of 2026-10-01 (the brief for review group T); `redwall-review/REVIEW.md` P6 (lines 948–964); the
review digest's SOC-001, SOC-014 and SOC-028; `docs/game_gdd.md` §5.3 and REQ-SET-035..042; `docs/setting_bible.md`
§3.2, §13.2 (DEC-016) and §13.3 (DEC-017); `docs/setting_decisions.md` DEC-017 and DEC-041.
