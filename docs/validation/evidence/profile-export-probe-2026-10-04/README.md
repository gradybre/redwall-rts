# Isolated cached-source export capability

This tiny Godot 4.7.2 project tests packaging behavior only. It does not qualify
the complete demo, Windows native execution, renderer attachment or gameplay.

The current Windows preset uses script export mode2 and does not include raw
`.ugprof` files. Running the isolated exported pack through the editor confirms
both consequences: the actual loaded Script is cached and is the executing
object, but its source has length 0; the raw profile file is absent.

Changing the isolated preset to mode0 and explicitly including`.ugprof` keeps
nonempty actual cached Script text (180 characters) and the raw file.
This probe checks retained text length, not byte-for-byte equality. Both installed
macOS export templates also execute this project with those facts:

| Execution | Script text | Raw file | Template | Debug |
|---|---:|---|---|---|
| Mode2 pack/editor |0|absent|false|true|
| Mode0 pack/editor |180|present|false|true|
| Mode0 native debug |180|present|true|true|
| Mode0 native release |180|present|true|false|

Every row also reports`cached=true`, `source_matches_cached=true` and the
executed owner value 17. All 9 final invocations exit0 with no raw unexpected
error/warning or leak reports. Source pins are unchanged. See`v3/invocation.json`,
the raw logs, `verification.json` and`source-and-output-sha256.json`.

The source project is retained. Reproduce its exact import and export commands
from the invocation. Native templates must boot the configured main loop with
`--headless`; they do not accept editor path/script overrides. Unpack the
generated app and make its MacOS binary executable before that invocation.
Large generated archives and app bundles are not evidence committed here;
the invocation records the archive hashes.

Earlier exploratory logs are retained separately: the first macOS export
refused disabled ETC2 ASTC, and an initial unsupported native`--script` attempt
timed out after 50 seconds. The wrapper terminated only its own child. Neither
attempt is counted as a pass. The final isolated project enables the required
texture-import setting and uses its configured main loop. No shared project,
library, export preset or user process was changed by this probe.

The proposed full-demo change remains decision1127's separate implementation
and real pack-verification gate. Runtime startup and memory effects of source
retention still require full-client qualification.
