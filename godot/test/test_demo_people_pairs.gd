extends "res://test/framework/test_case.gd"
## The people's shared-work pairs found by bucket (people_taps.gd PAIRS BY BUCKET, decision 1004): every pair the old
## loop over all pairs found at work together is among them, each once, in the old order -- over a hundred residents
## placed at random on digs and board tasks of a few crews, many times. No scene tree, no assets.

const Ledger := preload("res://demo/people/people_ledger.gd")
const TapsScript := preload("res://demo/people/people_taps.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")

const SEED: int = 1004
const COUNT: int = 120
const ROUNDS: int = 40


func _taps(rng: RandomNumberGenerator) -> TapsScript:
	"""Taps over COUNT residents and a work board of a few crews, its contexts set at random: a third on board tasks,
	a few at digs, everyone somewhere in 60 m."""
	var taps := TapsScript.new()
	taps.ledger = Ledger.new()
	taps.ledger.setup(COUNT)
	taps.calendar = CalendarScript.new()
	var board := BoardScript.new()
	var brains: Array[BrainScript] = []
	var keys: Array[StringName] = []
	var names := PackedStringArray()
	for i in COUNT:
		brains.append(BrainScript.new())
		keys.append(&"mouse_fieldworker")
		names.append("r%d" % i)
	board.bind(brains, names, keys)
	taps.board = board
	taps.watch()
	for i in COUNT:
		board.crews.crew_of[i] = rng.randi_range(0, 3)
		taps._task_of[i] = rng.randi_range(0, 99) if rng.randf() < 0.35 else -1
		taps._site_of[i] = rng.randi_range(0, 5) if rng.randf() < 0.1 else -1
		taps._at[i] = Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-30.0, 30.0))
	return taps


func test_the_pairs_by_bucket_are_the_pairs_at_work_together_in_the_old_order() -> void:
	"""Every pair `together` says yes to is a candidate, candidates are ascending (a, then b) with none twice, and the
	candidates `together` accepts are exactly the old loop's pairs, in its order."""
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var differ := 0
	var together_pairs := 0
	for round_index in ROUNDS:
		var taps := _taps(rng)
		var expected := PackedInt64Array()
		for a in COUNT:
			for b in range(a + 1, COUNT):
				if taps.together(a, b):
					expected.append((a << TapsScript.PAIR_BITS) | b)
		var count := taps._shared_pairs()
		var got := PackedInt64Array()
		for k in count:
			if k > 0:
				assert_true(taps._pairs[k] > taps._pairs[k - 1], "ascending, each once")
			var a: int = taps._pairs[k] >> TapsScript.PAIR_BITS
			var b: int = taps._pairs[k] & TapsScript.PAIR_MASK
			if taps.together(a, b):
				got.append(taps._pairs[k])
		differ += 0 if got == expected else 1
		together_pairs += expected.size()
	assert_equal(differ, 0, "the old loop's pairs every round")
	assert_true(together_pairs > ROUNDS * 10, "a good many pairs at work together (%d)" % together_pairs)

