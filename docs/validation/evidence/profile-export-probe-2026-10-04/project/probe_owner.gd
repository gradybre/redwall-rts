extends RefCounted
## Isolated cached-script text witness, not a game owner.

static func value() -> int:
	"""Ensure this actual resource was loaded and can execute."""
	return 17
