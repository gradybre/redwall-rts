# 0022 — `required_skill` is a minimum level in the job's own skill
Date: 2026-09-06 · Status: **Accepted** (Brendan, 2026-09-06)

## Decision
```
skill_index  = Job.kind
skill_passes = resident.skill_level[skill_index] >= Job.required_skill
```

| Value | Meaning |
|---|---|
| 0 | No minimum experience required |
| 1–10 | Minimum level in that job's skill |
| Outside 0–10 | **Invalid job definition** |
| `RESERVED_3` | **Invalid productive job kind** |

## Why this needed a ruling
§4.3 makes `JobKind` and the skill index the **same number**, so reading
`required_skill` as "which skill" carries no information — while §5.3's step 4
explicitly demands a skill test. The field name is kept for compatibility, but it
means *minimum required skill level* everywhere.

## Consequences
- Default stays **0**. Do not introduce additional minimums unless a recipe or
  task definition specifies them.
- Boundary tests must cover **one level below, exactly equal, and one above**.
- **Party members are checked individually.** Crew-average fishing skill affects
  the catch calculation, not individual eligibility.
- A value outside 0–10, or any job of kind `RESERVED_3`, is an invalid
  definition and must be refused rather than clamped.

## Source
Brendan, 2026-09-06, ruling on an ambiguity raised during job-store implementation.
