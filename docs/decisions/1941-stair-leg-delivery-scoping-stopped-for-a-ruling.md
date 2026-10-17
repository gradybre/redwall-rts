# 1941 — Stair-leg Delivery: scoping, stopped for a ruling

Date: 2026-10-17 · Status: Proposed. Follow-up 4 of the C2 follow-ups (the coordinator, 2026-10-17). Nothing is built
for it; the lane stops here for the ruling in §3.

Branch `feat/room-dig-followups`. Number range 1938–1949.

## The request

Decision 1981's P-1981-4 (a) gives C2.3 Delivery's leg-by-leg reach and the hauler's leg list over the stair carry
rows (71–84), so that an upstairs staging container can supply a dig below. The coordinator's terms: prove it on
what exists (H ↔ sill); retire `ROOM_HAUL_NO_STAIR_CARRY` only where a real path exists and keep it for levels
without one; the floor end is deferred to M5 (decision 2043's level-1 flight). Slice D's 2b-2 (earth carry,
content 13) will edit Delivery, the hauler and the room builder later, and adds earth at 5,000 milli-U, so the
stair trip's quantity must come through the grip certificate (`Grip.QUANTITY_MILLI`, or `quantity_of` where it
exists).

## 1. What exists (checked at `b4cceb65`)

- **The stair carry runs from H to the sill and back** (decision 1972, "Switch on without floor end").
  `underground_entry_stair_path.gd` `carry_plan()` publishes 17 CARRY edges once the sill is in: H → A(L0) (the
  approach, rows 73/79), the descents down to A(T6) (74/80), the half-turn A(T6) → U(T6) (76/82), the ascents up to
  U(L0) (75/81) and U(L0) → H (the retreat, 77/83). The walk-off and back-up (rows 71/72, 78/84) have no edge.
- **The sill is a stair tread, not a place to put stock down.** No storage Location and no stand stands on it.
  Decision 1981 §1: the level carry (rows 32/37) cannot stand on a stair tread (its all-yaw stance is ±375 u on a
  512 u run), so a ground carry or a grip set-down there has nowhere to stand.
- **No room level is below the stair.** The stair ends at the sill (local y −896). Rooms are admitted only at a
  roofed level's authored floor; level 1's floors are −5,632, −4,608 and −3,584 (decision 1972, "What the stair
  carry supplies"). Room digs on level 1 wait for M5's flight.
- **The empty way back up has a gap at the sill.** The WALK edges there are T5 → T6 (descent) and U(T6) → U(T5)
  (ascent); there is no WALK half-turn on the sill. An empty mole that arrives at A(T6) cannot turn to climb. Below
  the sill, nothing is published.

So on what exists, a loaded mole can carry a unit from H down to the sill, turn there and carry it back to H. It
cannot deliver it anywhere below H, because nothing below H can receive it. **"An upstairs staging container
supplies a dig below" cannot be proven end to end until M5.**

## 2. What building it needs

As decision 1981 §3 lists, plus what this check found.

1. **A stateless leg helper over the live graph** (the stair path publisher's twin): from a ground stop to a
   lower stop, the loaded legs (ground CARRY 32/37 to H; the approach row; one route of the descent row; at the
   bottom, the walk-off row and ground CARRY to the destination stand) and the empty legs back (ground WALK to the
   bottom, the back-up, the half-turn, one route of the ascent row, the retreat, ground WALK). It reads the rows by
   the grip certificate's item, never a literal quantity.
2. **Delivery's leg-by-leg reach** (`underground_connector_delivery.gd` `_reach_stands`). Today it checks one
   CARRY profile over the whole way (`_reach(source, destination, carry_row)`), so a path over stair edges is
   refused. It becomes: ground carry to H, each stair leg by its own row (a static per-leg edge certificate, as
   Contacts' `_stair_reach_refusal` checks the WALK legs), then ground carry to the destination's stand.
3. **The hauler's carry stage as a leg list** (`underground_entry_hauler.gd`). Today `_lift` selects the automatic
   CARRY and requests one route to the destination's stand; the rooted stair rows are explicit, so the stage walks
   the helper's legs, switching rows at rest at each leg's end. The empty return is a second list.
   - **Save.** Either the leg list and its cursor are written in the hauler's record (a `Progress.MAX_WIRE_BYTES`
     bump, a section-6 count and a census row; the census is slice D's claimed file), or both are derived again
     on load from the live graph and the actor's Location (no wire change). The second is recommended.
4. **The room builder** (`underground_room_builder.gd`). `_level_refusal` admits two levels only when the helper
   finds the whole loaded way and the whole empty way back; otherwise `ROOM_HAUL_NO_STAIR_CARRY` stays. Its claim
   (`_plan_trips`, the swept footprint) must then cover the stair legs, row by row.

## 3. Proposal for the coordinator

**P-1941-1 — How to prove the stair-leg Delivery before M5.**

- **(a) Recommended: build it now on a two-level fixture, and prove the stair legs live.**
  - Items 1–4 of §2, with the derived save (no wire or census change).
  - End to end on a synthetic two-level route fixture: a short stair of qualified CARRY and WALK edges between two
    test decks, a staging container and stand on the upper deck, a room storage and stand on the lower deck, and
    the real Delivery, Reservations and hauler. Decision 1981's stair carry routes test already qualifies these
    edges on a test Space.
  - On the live entry (H ↔ sill): the helper's legs, and a loaded hauler carrying one unit from H down to the sill,
    turning and carrying it back to H over the real Routes, with no set-down.
  - `ROOM_HAUL_NO_STAIR_CARRY` stays raised for every live level, because none has a path until M5; the fixture
    proves the retirement where a path exists.
  - Cost: the largest item of the follow-ups; it edits the same three files slice D's 2b-2 edits.
- **(b) Defer it to M5.** Build and prove it once, end to end, on M5's real flight and floor end. Nothing churns
  under 2b-2, and no synthetic stair is maintained. The machinery waits.
- **(c) Build only the leg helper and the hauler's leg list now**, proved by the live H ↔ sill round trip.
  Delivery's reach and the room builder wait for M5.

## Note on M5

This record says M5 for the level-1 flight (decision 2043). Decision 1972 and decision 1981's activation inventory
call it F40; that naming is theirs and is not changed here.
