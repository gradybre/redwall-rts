# Schedule acceptance witness matrix

Planning only. Empty image explicitly fills hourly/current with ANYTHING1 and all other fields0. Base nondefault image sets row0present1, currentWORK2 and resolved1; it differs from a clear row.

| Field replaced by a correctly-sized allzero column | Invalid witness | Expected original code | A different substituted outcome |
|---|---|---|---|
| present | byte2 at row0 | COLUMN_PRESENT_BYTE | COLUMN_FREE_ROW due retained current/resolved |
| hourly_activity | byte4 | COLUMN_HOURLY_ACTIVITY | COLUMN_FREE_ROW because zero hourly data is invalid for other inactive rows |
| template | int3 at row0 | COLUMN_TEMPLATE_ID | accepted when zeroed |
| current_activity | int4 at row0 | COLUMN_CURRENT_ACTIVITY | COLUMN_FREE_ROW because zero current is invalid for inactive rows |
| sleep_satisfied | byte2 at row0 | COLUMN_SLEEP_SATISFIED_BYTE | accepted when zeroed |
| resolved | byte2 at row0 | COLUMN_RESOLVED_BYTE | COLUMN_UNRESOLVED_STATE because currentWORK remains |

Each assertion compares the exact code. Correctly sized zero substitutions can still refuse, which must not be mistaken for a surviving mutant. Swapping sleep/resolved changes the sleep2 witness to the resolved code. Swapping template/current changes a signed-negative current witness to the template-ID code. Parser errors never count.

Local state witnesses: present1/resolved0/currentWORK/sleep0 -> UNRESOLVED_STATE; present1/resolved0/currentANYTHING/sleep1 -> UNRESOLVED_STATE; present1/resolved1/currentWORK/sleep1 -> SLEEP_STATE. Valid latched state has currentANYTHING/resolved1/sleep1. Any activity with resolved1/sleep0 is permitted as history. For precedence, put a sleep-state fault on row0 and unresolved-state fault on row1; unresolved must win globally. Add an inactive hourlySLEEP residue on row2 and free-row must win over both.

The public history probe establishes legitimate edited-latch and reassigned-current cases; tests must replay those through public APIs and independently constructed saved fixtures. A template need not match its hourly slots or saved current activity. All three templates and four activities are admissible within those local state rules. No live Needs or clock is consulted by the validator.
