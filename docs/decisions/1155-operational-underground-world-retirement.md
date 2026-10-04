# 1155 — Retire underground authorities with their complete World

Date: 2026-10-04 · Status: engineering packet; implementation and acceptance open

## Problem and decision

Decision 1149 safely retires an unbound Session foundation. Operational Room,
excavation, payment and spatial Inventory bindings deliberately survive each
store's ordinary `clear()`. Dropping their owners leaves expired one-way weak
bindings, so merely clearing the stores cannot mount another operational World.
Privately nulling those fields would bypass the lifetime checks that prevent
an active settlement from replacing its paid or spatial authority.

Add an explicit whole-World retirement handshake alongside operational Session
activation. Preserve the existing one-way contract for the entire living World.
The handshake must identify the original actual host, Directory, full World
generation and exact original authority receivers. It is not an unbind option
on normal gameplay APIs and is not a room cancellation or a refund operation.

## Required sequence

1. Before EntityManager, EconomySystem or any settlement store changes, finish
   current-owner observations and prove that the original Session and all
   installed operational owners are quiescent. Refuse held cold/publication
   leases, Inventory or haul transactions, active observing/Work callbacks and
   partially prepared publications. Live settled rooms, material lots and
   jobs may exist: this is replacement of their entire World, not an attempt
   to cancel them individually.
2. Stop admission and fixed-tick dispatch on that original composition for the
   synchronous reset. Retain its actual authority objects until their stores
   release the bindings. Do not expose a replacement World or another owner
   between preflight and completion. Existing staged WorldInit data remains
   governed by decision 1149.
3. Use the actual host's existing store-clearing path. The original Directory
   must have retired the complete World and its entities, and every affected
   store must be empty before lifetime links can be released. Clear alone must
   continue to preserve the one-way binding; a second, explicit owner API owns
   release. Inventory must prove the same actual Directory through its original
   spatial composition, not accept an unrelated empty Directory supplied by a
   caller. Expected authority identity, whole-World identity and empty-store
   evidence are conjunctive requirements.
4. Validate all release leaves before changing any binding. The release tail
   must use concrete original receivers without observers, await, signals or
   allocation. It may clear only the expected links, derived script handle and
   old World handle belonging to the retiring composition. It must not create
   another store, rewind entity generations, resize the Inventory endpoint
   arena or erase ordinary once-bound protection while a World remains live.
5. Drop the retired Session and its private owners, then initialize the next
   Session against the newly published full World identity. Every old command,
   actor, route, Location and authority handle must refuse against that World.

An expired authority that the Session did not retain, a foreign receiver or a
partially cleared tuple is a wiring refusal, not permission to forget a link.
Repeated preparation by the existing boot/UI reset call chain must be safe and
must not clear a store twice. Foundation-only retirement remains supported.
Operational activation cannot ship with restart permanently disabled.

## Ownership and acceptance

The integration owner coordinates Session, SettlementSystem and the existing
Buildings, Construction, Work and Inventory owners. The retired-authority API
must be agreed and narrowly leased before implementation; no agent may modify
another active source lane. The existing live GroundPiles, Gear, Reservations
and item registry lifetime must remain consistent with host reset/remount.

Tests must cover actual operational bindings, populated settled stores, every
preflight refusal with unchanged state, live-World and partial-clear release
refusal, expired/foreign/equal-number receivers, held publication/transaction
brackets, successful reset/remount and stale handles after generation reuse.
The real demo boot/Create/restart sequence must pass once operational activation
is integrated. Independent review, strict diagnostics/leak gates, zero-warning
analysis and a complete source-derived control/helper census are required.
No additional packed bank or higher reserve ceiling is adopted here.

This packet does not claim an operational Session, completed teardown or a
playable Kitchen. It closes a known implementation contract needed by UG24;
all 107 requirements and the whole-workflow acceptance gates remain in force.

## Sources

Decision 1149; the current Session `reset_refusal`/`retire_foundation` and
SettlementSystem `prepare_world_reset`/`reset` sequence; once-bound authorities
in Buildings, Construction, Work and Inventory; Brendan's approved concurrent
implementation and whole-demo integration instructions.
