extends RefCounted
## Dig crews, the Foremole and digging experience. Decision 0196 (live demo). Presentation only.
##
## ---------------------------------------------------------------------------------------
## A CREW belongs to a tunnel: the Foremole (the mole digging it, or doing its mole-work -- widening,
## clearing a collapse, digging a chamber) leads, and up to MAX_BUILDERS - 1 more residents join
## (ECON-002: "a project has at most 4 builders"). Those who fit the bore work underground behind
## the Foremole; those who do not -- an otter, the badger -- work the entrance as surface hands.
##
## THE CREW'S RATE follows ECON-002/003 exactly as far as they go: at most ONE worker at each
## quantum's work face, and shared progress never inflated. A bore's cross-section offers FACES
## quanta side by side (1 in a standard bore; 5 more per metre when widening), so up to FACES
## workers each cut their own quantum. Beyond that a worker can only FINISH behind a face: the
## face's lead then braces and cuts (25 + 50 ticks) while the finisher does the 38-tick finish of
## the quantum behind, so that face yields a quantum every 75 ticks instead of 113. So, in per mille
## of one F1000 worker (`pipeline_permille`): one worker 1000; two or more on a standard bore 1506
## (113/75, floored); on a widening, one per face up to four -- 2000, 3000, 4000. Surface hands add
## no face work.
##
## ROCK needs a breaker: while the face is in rock (tunnel_ground.gd), the rate is multiplied by
## ROCK_ALONE_PERMILLE (the mole scratches at it) unless a badger in the crew is at its post (demo).
##
## EXPERIENCE (demo): every quantum cut while a resident works the face adds one to its tally; the
## Foremole's tally raises the crew's rate by XP_STEP_PERMILLE per XP_QUANTA_PER_STEP quanta, up to
## XP_MAX_PERMILLE -- "a little", and never past a tenth.
##
## THE FOREMOLE'S LINES are original light mole dialect (DEC-017), not quoted from any book.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")

const MAX_BUILDERS: int = 4
const FACE_CYCLE_TICKS: int = Rules.BRACE_TICKS + Rules.CUT_TICKS
const XP_QUANTA_PER_STEP: int = 8
const XP_STEP_PERMILLE: int = 20
const XP_MAX_PERMILLE: int = 100
const BREAKER_SPECIES: String = "badger"

const LINE_START: String = "Foremole: \"Hurr, a gurt job this. Oi'll 'ave 'er dugged afore supper, burr aye.\""
const LINE_CREW: String = "Foremole: \"More paws, more tunnel! Stand be'ind oi an' finish wot oi cut, hurr.\""
const LINE_ROCK_ALONE: String = "Foremole: \"Burr, 'tis rock down yurr! Oi can scratch at 'er, but fetch ee badger to crack it.\""
const LINE_ROCK_BADGER: String = "Foremole: \"Hoo, that badger do crack rock loik 'azelnuts. Onward, zurr!\""
const LINE_OPEN: String = "Foremole: \"Thurr she be — a foine tunnel, clear through. Hurr hurr.\""
const LINE_SKILL: String = "Foremole: \"Moi paws be gettin' the knack o' this diggin'. Quicker now, burr.\""
const LINE_WIDENED: String = "Foremole: \"Wide enough fer a badger now, an' 'is supper basket too, burr aye.\""

## Per resident index: the tunnel slot it crews (-1: none), whether it is at its post, whether it
## is a rock breaker, and its digging experience in quanta cut.
var member_site: PackedInt32Array = PackedInt32Array()
var member_present: PackedByteArray = PackedByteArray()
var breaker: PackedByteArray = PackedByteArray()
var xp_quanta: PackedInt32Array = PackedInt32Array()
## Per resident index: the order it joined in (0 first), which sets its place behind the face.
var member_rank: PackedInt32Array = PackedInt32Array()


func set_resident(index: int, species: String) -> void:
	"""Know resident `index` (setup only: the columns grow here); a badger breaks rock."""
	if member_site.size() <= index:
		member_site.resize(index + 1)
		member_present.resize(index + 1)
		breaker.resize(index + 1)
		xp_quanta.resize(index + 1)
		member_rank.resize(index + 1)
	member_site[index] = -1
	breaker[index] = 1 if species.to_lower() == BREAKER_SPECIES else 0


static func pipeline_permille(workers: int, faces: int) -> int:
	"""The crew's rate, per mille of one F1000 worker, for `workers` at the work (the Foremole counted;
	at most MAX_BUILDERS) on `faces` quanta side by side (see THE CREW'S RATE)."""
	var n := clampi(workers, 0, MAX_BUILDERS)
	if n <= faces:
		return n * Rules.PERMILLE
	var finished := mini(n - faces, faces)
	return (faces - finished) * Rules.PERMILLE + finished * Rules.PERMILLE * Rules.TICKS_PER_QUANTUM / FACE_CYCLE_TICKS


static func xp_bonus_permille(quanta_cut: int) -> int:
	"""How much faster (per mille) a Foremole with this much experience digs."""
	return mini(XP_MAX_PERMILLE, quanta_cut / XP_QUANTA_PER_STEP * XP_STEP_PERMILLE)


func join(index: int, slot: int) -> bool:
	"""Put resident `index` on tunnel `slot`'s crew. False when the crew is full (the Foremole and
	MAX_BUILDERS - 1 others) -- or it is already on it."""
	if member_site[index] == slot or count_of(slot) >= MAX_BUILDERS - 1:
		return false
	member_site[index] = slot
	member_present[index] = 0
	member_rank[index] = count_of(slot) - 1
	return true


func leave(index: int) -> void:
	"""Take resident `index` off any crew; those who joined after it move up a place."""
	var slot := member_site[index]
	if slot < 0:
		return
	for j in member_site.size():
		if member_site[j] == slot and member_rank[j] > member_rank[index]:
			member_rank[j] -= 1
	member_site[index] = -1
	member_present[index] = 0


func disband(slot: int) -> void:
	"""Everyone off tunnel `slot`'s crew."""
	for j in member_site.size():
		if member_site[j] == slot:
			member_site[j] = -1
			member_present[j] = 0


func count_of(slot: int) -> int:
	"""How many residents (the Foremole not counted) crew tunnel `slot`."""
	return member_site.count(slot)


func set_present(index: int, present: bool) -> void:
	"""Whether resident `index` is at its post (the face, or the entrance for a surface hand)."""
	member_present[index] = 1 if present else 0


func face_workers(slot: int, fits: Callable) -> int:
	"""Workers at tunnel `slot`'s face: the Foremole, and each member at its post that `fits(index)`."""
	var n := 1
	for j in member_site.size():
		if member_site[j] == slot and member_present[j] == 1 and bool(fits.call(j)):
			n += 1
	return n


func breaker_present(slot: int, lead: int) -> bool:
	"""Whether a rock breaker is at work on tunnel `slot`: the Foremole itself, or a member at its post."""
	if lead >= 0 and lead < breaker.size() and breaker[lead] == 1:
		return true
	for j in member_site.size():
		if member_site[j] == slot and member_present[j] == 1 and breaker[j] == 1:
			return true
	return false


func rate_permille(slot: int, lead: int, faces: int, face_ground: int, fits: Callable) -> int:
	"""The rate tunnel `slot`'s crew digs at, per mille of one F1000 worker: the pipeline rate, raised
	by the Foremole's experience, slowed in rock with no breaker at work."""
	var rate := pipeline_permille(face_workers(slot, fits), faces)
	var xp := xp_quanta[lead] if lead >= 0 and lead < xp_quanta.size() else 0
	rate = rate * (Rules.PERMILLE + xp_bonus_permille(xp)) / Rules.PERMILLE
	if face_ground == GroundScript.ROCK and not breaker_present(slot, lead):
		rate = rate * GroundScript.ROCK_ALONE_PERMILLE / Rules.PERMILLE
	return rate


func credit_quanta(slot: int, lead: int, cut: int, fits: Callable) -> bool:
	"""`cut` more quanta were cut on tunnel `slot`: each worker at its face gains that much experience.
	True when the Foremole's rate went up a step."""
	if cut <= 0 or lead < 0 or lead >= xp_quanta.size():
		return false
	var before := xp_bonus_permille(xp_quanta[lead])
	xp_quanta[lead] += cut
	for j in member_site.size():
		if member_site[j] == slot and member_present[j] == 1 and bool(fits.call(j)):
			xp_quanta[j] += cut
	return xp_bonus_permille(xp_quanta[lead]) > before
