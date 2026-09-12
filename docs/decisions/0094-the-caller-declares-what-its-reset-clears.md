# 0094 — The caller declares what its reset clears

Date: 2026-09-12 · Status: **Accepted**

## Context

Pressing Create in a running game refused with `WORLD_FOREIGN_LIVE_ROWS`. Every
Create after a real boot failed; only the very first one worked.

This is the cohort-first change's own regression, and the archaeology matters
because the obvious suspect is innocent. `world_init._refuse_collaborators()`
did not change: it has always refused a live directory kind the generator does
not own, and it has always run before the reset it protects. What changed is
that `settlement_system.gd` began allocating `KIND_RESIDENT` directory rows —
introduced by `c64d01a`, the commit that gave the cohort ids 1–12. Before it,
residents held no directory rows, so the gate had nothing to trip on. After it,
a booted settlement leaves twelve resident rows sitting in the directory, and
`preflight()` sees twelve rows it does not own.

The suite could not see this. Every existing test pressed Create on a fresh
settlement, where the directory is empty and the gate has nothing to refuse.
It took a native screen capture of a booted game to find.

## The mistake in the gate's question

The gate exists to stop a reset orphaning a row owned by a store the generator
was never given. The property it wants is **"will anything clear this row"**.
The property it tested is **"do I own this row"**.

Until the cohort work those were the same question, because every live kind was
either the generator's or nobody's. The cohort broke the equivalence: resident
rows are cleared — by the caller's own `reset`, the Callable that caller passes
in alongside. They were never orphan risks.

## Decision

The caller declares which directory kinds its reset clears.
`world_init.declare_externally_cleared(kinds)` sets one bit per kind in a
scalar mask, and `_owns_kind()` consults it first. A `PackedByteArray` of
`KIND_COUNT` was written first and replaced: `KIND_COUNT` is 18, comfortably
inside an int, and the array form cost an §2.3 allocation row and a registry
column — `state_registry_coverage` failed on it — to store eighteen bits. The
mask is generation scratch exactly like `_foreign_kind` beside it. `ui_world_session.gd` declares exactly
`KIND_RESIDENT`, beside the `reset` Callable it already passes.

Three things this deliberately is not:

- **Not ownership.** The generator still never touches or clears a resident
  row. Adding `KIND_RESIDENT` to `_owns_kind()`'s match would have been a lie
  that happened to work only while the caller's reset cleared them.
- **Not an amnesty.** A kind nobody declares still refuses, still names itself
  through `foreign_kind()`, and still leaves the row untouched.
- **Not sticky.** Each declaration replaces the previous one. A generator
  outlives one call, and a permission granted for a composed create must not
  silently survive into a plain one.

The caller that supplies an opaque `reset` Callable is the only object that
knows what that Callable clears, so it is the only object that may say so.

## Consequences

Create works in a running game, and the cohort still takes ids 1–12 — the
regression is fixed without giving back what the fix bought.

Six mutations, all killed. Three of them needed tests written first, and each
had survived for the same structural reason: **the new door could not be
reached from any existing test**, because every foreign-row test built a
generator that never declared anything at all.

- Declaring every kind instead of the named ones — survived until a test
  declared one kind and asserted a *different* one still refuses.
- Sizing the mask one short — survived until a test declared `KIND_WORLD`, the
  last kind, which is the only index that falls off the end. (Written against
  the array form; the test outlived it and still pins the boundary.)
- Dropping the `fill(0)` so declarations accumulate — survived until a test
  declared a kind and then withdrew it.

The lesson is the same in all three: adding a permission path adds a surface
that no existing test covers by construction, because those tests predate it.

One mutation is left alive as genuinely equivalent, and it is the same change
that motivated the encoding: relaxing the bound to `kind <= KIND_COUNT`. Against
the `PackedByteArray` form it wrote one past the end and a test killed it.
Against the mask it sets an unread bit — `_owns_kind()` is only ever asked about
kinds `0..KIND_COUNT - 1` — so nothing observable differs. The guard still earns
its place by stopping a large `kind` from shifting past the int, which is not
equivalent; only the off-by-one at exactly `KIND_COUNT` is. The boundary test
that killed the array version is kept: it pins that declaring the last kind
works, which is a property of the mask too.

`create_into()`, the non-cohort path, declares nothing and is unchanged; it
runs `generate()`, whose own reset handles its own stores.
