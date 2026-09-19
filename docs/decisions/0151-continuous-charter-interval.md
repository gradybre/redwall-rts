# 0151 — Count complete tick intervals for the Hearth Charter

Date: 2026-09-19 · Status: Accepted timing contract; runtime integration pending

The Charter keeps its GDD winter-day12 midnight award time and all thresholds.
[PROGRESS-C4-R01](../rulings/2026-09-19_progression_interval.md) resolves the
ambiguous three-day maintenance wording as truth at both endpoints and every
committed tick between T−54000 and T. A single failure breaks the interval;
three midnight snapshots never prove continuity.

Independent Claude review checked the calendar and exposed pause ownership,
aggregate cadence, specialist eligibility, cumulative-counter ownership and
reward retry gaps. Astra's version2 [execution package](../planning/progression_execution_package.md)
records their dispositions. Its new internal COLLAPSE reason, pending reward and
87-byte proposed Progress layout are explicit future integration changes, not
claims of existing code or active save compatibility.

Implement only a stateless checked interval helper now. The shared-owner startup,
full progression facts, producers, persistence and UI remain separate tasks.
This closes an authored temporal ambiguity without asserting three-year survival
or changing the scope of the settlement release.
