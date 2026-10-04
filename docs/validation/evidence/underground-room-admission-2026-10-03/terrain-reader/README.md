# Actual Building facts for Terrain

Decision1083 narrow follow-up requested by Terrain1082. Only the existing Buildings source and spatial test changed; no persistent state or geometry qualification is added. Source pins are final.

Clean own-worktree import (demo assets absent), strict singleton CI shards and analyzer `--max 0 --port 6156` produced84 tests/1340 assertions/0 failures, all diagnostic/raw unexpected and leak counts0, analyzer0/2. The first test attempt incorrectly called nonexistent `remove_building` twice; the retained historical log records21 tests/370 assertions/2 failures and is not passing evidence. Correcting those fixture calls to the existing `demolish_building` method left production source unchanged, then both affected suites and analyzer passed.

Parent independently reviewed the production reader and adversarial tests. The caller owns its four-I32 scratch array (16 bytes); the reader creates no packed array or OpResult and resizes nothing. This is an actual Building-identity read, not terrain/contact qualification.
