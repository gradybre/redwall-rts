# Rejected execution ordering

The self-clearance proof was still writing its own log when the native wrapper pinned every file in the preview directory. The pre-import source check correctly refused before native rendering. Only the proof log changed; no source or geometry was accepted under drift. Both original pin images and raw failure are retained. The corrected run starts in a fresh output directory after the self proof finishes.

Changed file: ['/Users/brendan/Developer/redwall-rts-codex-ug-space/godot/data/underground/mole-worker/evidence/contact-qualification/stair-descent-v7/self-v1.log']
