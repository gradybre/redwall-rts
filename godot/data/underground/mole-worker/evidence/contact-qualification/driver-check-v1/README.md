# Rejected initial driver fixture

The first clean import completed, but the strict singleton suite refused a
constructed PackedInt32Array constant in the test fixture. The suite did not
load:1 test,0 assertions,2 failures and one unexpected script error. Its exit
was nonzero. Raw import/test logs, selected shard and executed source pins are
retained. No driver execution or qualification is claimed for this attempt.

The following runs replace that fixture declaration with a constant typed
Array and then correct the independently found WORK role-binding defect.
