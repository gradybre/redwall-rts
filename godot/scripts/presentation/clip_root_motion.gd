extends RefCounted
## A clip's root motion, as tools/ground_meshy_clips.py recorded it. Decision 0195.
##
## ---------------------------------------------------------------------------------------
## THE CLIPS PLAY IN PLACE. Crowd architecture 9.1 fixes the in-place root convention, and the fixed-tick
## simulation owns movement (crowd 1383): animation never decides where a creature is. Meshy's two
## carry walks travelled 0.6-3.2 m per loop, and a clip that travels snaps back at every loop -- a
## live tail spring measured a 122-169 degree one-frame whip there. So the grounding step took the
## travel out of the hips, keeping each stride's own sway, and recorded what it took on the Hips
## bone's glTF extras, which Godot imports as bone metadata `extras`:
##
##   root_motion = {period_s, travel_m: [x, z], mean_speed_m_s, window_s, keys_xz: [[x, z] per key]}
##
## A clip without the entry does not travel. The presentation moves the creature where the
## simulation says; `playback_rate()` is how fast to play the clip so its strides match that speed.

const MIN_SPEED_M_S: float = 1e-4


static func read(skeleton: Skeleton3D) -> Dictionary:
	"""The recorded root motion of the clip on `skeleton`, or {} if it plays in place."""
	var hips := skeleton.find_bone("Hips")
	if hips < 0 or not skeleton.has_bone_meta(hips, &"extras"):
		return {}
	var extras: Dictionary = skeleton.get_bone_meta(hips, &"extras")
	return extras.get("root_motion", {})


static func playback_rate(motion: Dictionary, ground_speed_m_s: float) -> float:
	"""Play a travelling clip at ground_speed / its own mean speed, so a planted foot does not slide.
	A clip with no root motion plays at 1."""
	var clip_speed: float = float(motion.get("mean_speed_m_s", 0.0))
	if clip_speed < MIN_SPEED_M_S:
		return 1.0
	return ground_speed_m_s / clip_speed
