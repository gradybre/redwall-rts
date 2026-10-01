# 0442 — The otters' songs: four original pieces, sung only in their context, taught by hearing, hummed on their own bus
Date: 2026-10-01 · Status: Accepted (the texts await Brendan's review)

Numbered in this lane's block (0441–0449; see 0441). Brendan approved water part B, "otter songs" among it
(2026-10-01). The review's **SOC-026** (a community repertoire: original short pieces for work, gathering and
remembrance; the player can prefer or mute them; verses may reference local deeds through authored slots, never canon
text), **UX-030** (diegetic singing kept separate from the score) and **UX-032** (selective voices; subtitles) set the
terms; the digest adds "no species caricature". DEC-021 (`docs/setting_decisions.md`) adopts "a contextual mix of
acoustic music, ambience, singing, quiet and orchestral adventure"; DEC-017 "distinct voices with light dialect",
plain functional UI; LORE-T06 "personalities exceed species stereotypes"; LORE-T07 "memory accumulates honestly".

## Decision

### The originality rule

**Every word of every song is written for this demo.** No name, line, refrain or phrase is taken or adapted from any
Redwall book or any other published song; no character, place or creature name from the books appears, and none is
invented to sound like one. The songs live in **data** (`godot/demo/songs/songs.json`), so they can be reviewed,
replaced or cut without code. `test/test_demo_songs.gd` guards the rule mechanically for the obvious failure (a list
of the books' best-known names must not appear in any title or line); the rule itself is this record's, and a human
reads the texts below.

### The tone

Warm woodland-folk: plain, concrete, communal -- loads, rain, bread, a bench with room on it, a heron at dusk. Light
on dialect (DEC-017): ordinary spelling, no phonetic accent, no nautical "otter talk", nothing that makes the singers'
species the joke (no caricature). The songs are about the village's day, not about otters. Short lines -- one line at
a time fits a bubble -- and a slant rhyme in couplets.

### The songs (all four, as shipped)

**The Long Pull** (`work_long_pull`) -- work: hauling, carrying, at a task

> Heave and set, and heave again,
> the load's no lighter for the rain;
> one more step and one more stone,
> no back was ever bent alone.
> Pull for the bank and pull for the bend,
> the stream's a road with a willing end.

**Lift and Lay** (`work_lift_and_lay`) -- work

> Lift it high and lay it low,
> sing it light and work it slow;
> the sun is climbing, so are we,
> and supper's waiting, wait and see.

**Set the Board** (`supper_set_the_board`) -- supper, at the table

> Bring the bowls and bring the bread,
> bring the ones the river fed;
> shift along and make some room,
> there's lamplight yet against the gloom.
> Whoever's late, we'll keep a share;
> the bench is long, there's room to spare.
> A cup for {deed}!  *(no deed recorded: "A cup for the cook!")*

**The Heron's Hour** (`evening_herons_hour`) -- the quiet evening

> Slow now, the water's going grey,
> the heron's tucked his legs away;
> hang the net and bank the coal,
> the dark will keep us, safe and whole,
> and tell of {deed} tomorrow.  *(no deed recorded: "and tell of the day tomorrow.")*
> The stream can do the singing now.

### Verse slots: recorded deeds only

A song may carry one `{deed}` slot. It is filled only from what the village has **recorded** (LORE-T07): each bridge
it has opened ("the weir bridge", from the water play's bridge names) and, after a rescue, "the swimmer saved" --
else the song's own fallback words. The demo has no chronicle yet; when one exists, it is the slot's source.

### The limits (data rules, enforced at load)

- An **id per song**, unique; a title; one context (`work`, `supper`, `evening`); **4 to 8 lines**; a tune.
- **No line longer than 44 characters** (`line_limit`) with its slot filled by the longest deed allowed
  (`deed_limit` 20); a slot must have a fallback. A book that breaks a rule is refused whole, saying which song and
  line; then nobody sings (a warning at boot).

### Who sings, and when (`songs/song_circle.gd`, `songs/demo_songs.gd`)

- **Only in context, and never in the way.** A resident's context is read a few times a second from what it is
  already doing: **work** while actually working -- carrying a load, at an order's work, at a kitchen step, or
  holding a work-board task that is working or hauling, never while walking to it -- by day; **supper** while seated
  at the supper table (the kitchen's own eating step); **evening** from 19:00 to 22:00 while wandering free or walking
  home to bed. Underground, indoors, hidden or lying down: none. A song stops the moment its singer leaves its context.
  The songs read the residents, the kitchen, the night and the work board, and **write into none of them**: they never
  hold a job, a meal or a bedtime.
- **The otters know every song; others learn.** Anyone who hears a song sung **to its end twice within 6 m** learns
  it and sings it from then on, in its context -- so the songs spread through the village by being sung near people.
  Learning is a routine Village news line, once per resident and song, naming the teacher: "from the otters" when an
  otter sang it, else the singer by name.
- **Pacing**: a line every 3.2 real seconds while the game runs (paused, the line holds; the singing is the player's
  to read, so it does not speed up at 2x or 4x); a rest of 40–60 s after a song (staggered per resident; 8 s after a
  song cut short); the first song comes 5 s × (row + 1) into the session. **At most two** lead at once.
- **Supper is one table**: one leads; everyone seated who knows the song joins, shown as "♪ ♪" (not the words again).
  The day's first supper song is a routine news line ("At supper Otter fisher led “Set the Board”, and the table
  joined in."). Work and evening songs make no news: the feed stays uncluttered.

### Presentation

- **Bubbles**: one line at a time, "♪ " and the line, in a parchment bubble (oat, an umber rim) over the singer's head
  on the screen (`songs/song_view.gd`, a pool of 8, under every HUD and demo panel). Their words are rebuilt only when
  a line changes. The bubble is the songs' text match: with the sound off nothing is lost (UI §7).
- **Settings** (the game menu's Sound section): **Residents sing: on / off** (`sound_mix.gd songs_on`) -- off, nobody
  sings, hums or makes song news, and a song in progress stops -- and the **Songs** bus's own volume and **Mute**.

### The audio choice

**A synthesised hum, no new files, on its own bus.** The demo's CC0 audio library holds nothing voiced, and nothing is
downloaded. Each song's `tune` (semitones over G3, 196 Hz, in eighths) is synthesised once into an in-memory
`AudioStreamWAV` -- a closed-mouth hum: a sine with two quiet overtones (0.28, 0.10), a 5 Hz vibrato of 0.4 %, each
note eased in over 50 ms and out over 90 ms, peak about 30 % of full scale -- during the boot prewarm (about 10 ms a
song, 42 ms for all four, measured headless). A phrase plays **as each line begins**, positional at the singer, 14 dB
under the bus, gone by 18 m, at most three at once (a busy pool skips it). It is on a sixth bus, **Songs** (Balanced
50 %, Quiet focus 25 %, Atmosphere 65 %; low-passed in the U view like the world above). Rejected: Godot's
`AudioStreamGenerator` pushing frames each frame (per-frame work for a fixed phrase that can be made once); a staged
pluck from the CC0 interface pack (an instrument, not a voice; it would read as a UI click). It is **diegetic and never
a score**: the demo has no score, and nothing here would play one (UX-030).

## Why

- SOC-026's repertoire in its smallest honest form: three contexts the village already has (work, supper, the walk
  home), sung by the residents who know them, spreading by being heard, and naming only what happened.
- Context-gated and read-only, so a song can never make a resident late for work or a meal.
- Text first (bubbles), sound second (a quiet hum on its own bus): mutable twice over, never needed to understand
  anything.

## Consequences

- New songs are data: add an entry to `songs.json` (the load enforces the limits; `MAX_SONGS` 16, one bit each).
- Lane 1's boats and fishing count as work through the same reads (a resident working or holding a working task);
  no change is needed there for a fisher to sing.
- Brendan reviews the texts; a text he rejects is replaced in the data, and this record is updated with the new words.
- Open: UX-030's village motif and score; UX-032's named voices; a chronicle as the slots' source; a remembrance
  piece (SOC-026's third kind) once there is something to remember.

## Evidence

`test/test_demo_songs.gd` (21 tests): the book (an id per song, 4–8 lines, every line within the limit with its slot
filled, the names guard, a broken book refused), songs only in their context, stopping out of it, paused holding,
resting, the two-lead cap, supper's one table and its once-a-day news, learning by two hearings in earshot, the
switch silencing everything, the Songs bus and its presets and its U-view filter, the hum's synthesis and one phrase
a line, the residents' contexts (supper seats, working and hauling board tasks, the cook, lying down), teaching by
name. Cost: the circle's step over every resident, 600 frames headless (Apple Silicon): 5 µs at 12 residents, 14 µs at
64, 34 µs at 256. Frames in
`scratchpad/weir_check/`: a work song, the supper song and the evening song over their singers in the running demo.
The mutation run is 0441's (shared).

## Review

The independent `code-reviewer`: no CRITICAL. HIGH, fixed: the circle scanned the village for the lead count and the
supper lead at every start attempt -- n² a frame, 827 µs at 256 residents; both are now counters kept as songs start
and stop (34 µs). HIGH, fixed: the supper, work-board, hum and Songs-filter paths had no test (see Evidence). LOW,
fixed: bubbles and heads are computed only for singers; the hum is stopped once when the songs are switched off, not
every frame; any of a resident's tasks working counts, not only its first; a learner teaches in its own name; the
choice list is reused. LOW, left: the bubble's placement on screen is checked in the running demo's frames, not by a
headless test (the suite's worker runs outside the scene tree).

## Source

Review SOC-026, UX-030, UX-032 and the digest's notes (`review_digest/part2.md`); Brendan's approval of water part B
(2026-10-01); DEC-017, DEC-021, LORE-T06, LORE-T07 (`docs/setting_decisions.md`, `docs/setting_bible.md`); decisions
0331 (village news), 0351 (the sound pass and its buses), 0381 (the kitchen), 0411 (the work board), 0421 (the
evening hours: supper to 19:00, dusk 20:00).
