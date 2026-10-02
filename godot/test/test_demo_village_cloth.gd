extends "res://test/framework/test_case.gd"
## THE VILLAGE'S ONE CLOTH (decision 0993; Brendan's ruling on the review's R01, 2026-10-02): the hall's tier-2 upgrade,
## the infirmary building and the treatments all reserve and debit the one cloth in the village stores
## (tunnel_stores.gd CLOTH), which holds GDD §5.1's opening 24 U. Each lane's own tests conserve its own books; these
## check the three together -- two individually conserving copies of the cloth would pass those and fail here.

const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const HallRules := preload("res://demo/hall/hall_rules.gd")
const HallProjects := preload("res://demo/hall/hall_projects.gd")
const InfRules := preload("res://demo/infirmary/infirmary_rules.gd")
const InfProject := preload("res://demo/infirmary/infirmary_project.gd")
const CareState := preload("res://demo/infirmary/care_state.gd")
const Injury := preload("res://scripts/core/injury.gd")

const OPENING: int = 24000
const UPGRADE: int = HallRules.PROJECT_UPGRADE
const H_CLOTH: int = HallRules.MAT_CLOTH
const I_CLOTH: int = InfRules.MAT_CLOTH
const TREATMENT_CLOTH: int = 500
const RESIDENTS: int = 4


class Village:
	"""The three claimants over one village stores, with plenty of wood and stone."""
	var stores: StoresScript = StoresScript.new()
	var hall: HallProjects = null
	var infirmary: InfProject = null
	var care: CareState = CareState.new()

	func _init() -> void:
		"""Stores with the opening cloth and wood and stone to spare; the hall unlocked; RESIDENTS care rows."""
		stores.wood_milli_u = 200000
		stores.stone_milli_u = 200000
		hall = HallProjects.new(stores)
		hall.unlocked = true
		infirmary = InfProject.new(stores, RESIDENTS)
		var sizes := PackedByteArray()
		sizes.resize(RESIDENTS)
		care.configure(sizes, -1)
		care.use_cloth(stores)


func _accounted(v: Village) -> int:
	"""Every milli-U of the opening cloth: in the stores, in arms or delivered to either building, built into either,
	or taken by a paid treatment."""
	var total: int = v.stores.cloth_milli_u
	total += v.hall.transit[v.hall.cell(UPGRADE, H_CLOTH)] + v.hall.delivered[v.hall.cell(UPGRADE, H_CLOTH)]
	total += v.infirmary.in_transit[I_CLOTH]
	if v.hall.phase[UPGRADE] == HallProjects.PHASE_DONE:
		total += HallRules.need_milli(UPGRADE, H_CLOTH)
	if v.infirmary.state != InfProject.STATE_NONE:
		total += v.infirmary.delivered[I_CLOTH]
	return total + _paid(v) * TREATMENT_CLOTH


func _paid(v: Village) -> int:
	"""Treatments whose inputs are paid and not yet completed (each took its 0.5 U)."""
	var n: int = 0
	for i: int in RESIDENTS:
		n += 1 if v.care.is_paid(i) else 0
	return n


func _check(v: Village, what: String, opening: int = OPENING) -> void:
	"""The cloth is conserved (`opening` of it: the opening 24 U unless a test set the stock), and no claimant has
	reserved more than the stores hold."""
	assert_equal(_accounted(v), opening, "%s: the opening cloth all accounted for" % what)
	assert_true(v.stores.cloth_claimed() <= v.stores.cloth_milli_u, "%s: claims within the stock" % what)


func test_one_opening_stock_of_24_u_serves_both_buildings() -> void:
	"""The review's reproduction: build the infirmary (12 U) and upgrade the hall (8 U): 4 U remains, not 28."""
	var v := Village.new()
	assert_equal(v.stores.cloth_milli_u, OPENING, "GDD §5.1: one opening 24 U")
	assert_equal(v.hall.cloth_milli, OPENING, "the hall reads the stores' cloth")
	assert_equal(v.care.cloth_milli, OPENING, "and so does the care shelf")
	v.hall.plan_upgrade()
	v.infirmary.plan_at(Vector2.ZERO, 0.0)
	_fetch_all_cloth(v)
	assert_equal(v.stores.cloth_milli_u, 4000, "24 - 12 - 8 = 4 U left")
	_check(v, "both delivered")
	_build_both(v)
	assert_equal(v.stores.cloth_milli_u, 4000, "4 U after building both")
	_check(v, "both built")


func _fetch_all_cloth(v: Village) -> void:
	"""Every material of both projects reserved, lifted and delivered."""
	for mat: int in HallRules.MAT_COUNT:
		var need: int = v.hall.outstanding(UPGRADE, mat)
		v.hall.deliver(UPGRADE, mat, v.hall.lift(UPGRADE, mat, v.hall.reserve(UPGRADE, mat, need)))
	for mat: int in InfRules.MAT_COUNT:
		var want: int = v.infirmary.outstanding(mat)
		v.infirmary.deliver(mat, v.infirmary.lift(mat, v.infirmary.reserve(mat, want)))


func _build_both(v: Village) -> void:
	"""Both projects' work done."""
	assert_true(v.hall.add_work(UPGRADE, v.hall.work_total_usec(UPGRADE), 1), "the hall raised")
	assert_true(v.infirmary.add_work(InfRules.work_usec()), "the infirmary built")


func test_a_reservation_is_never_free_to_another_claimant() -> void:
	"""The hall's reserved cloth cannot go to the infirmary or a treatment, and theirs not to the hall."""
	var v := Village.new()
	v.hall.plan_upgrade()
	v.infirmary.plan_at(Vector2.ZERO, 0.0)
	v.stores.cloth_milli_u = 9000
	assert_equal(v.hall.reserve(UPGRADE, H_CLOTH, 8000), 8000, "the hall reserves 8 U")
	assert_equal(v.infirmary.fetchable(I_CLOTH), 1000, "only 1 U is free to the infirmary")
	assert_equal(v.infirmary.reserve(I_CLOTH, 12000), 1000, "it reserves that")
	assert_equal(v.stores.cloth_free(), 0, "nothing free")
	v.care.hurt(0, Injury.KIND_CUT, Injury.SEVERITY_MINOR, 5)
	assert_equal(v.care.treatment_refusal(0), CareState.REFUSE_NO_CLOTH, "a treatment waits: no cloth")
	assert_equal(v.care.pay_treatment(0), CareState.REFUSE_NO_CLOTH, "and pays nothing")
	v.hall.unreserve(UPGRADE, H_CLOTH, 500)
	assert_true(v.care.claim_cloth(0), "half a unit given back: the treatment reserves it")
	assert_equal(v.hall.fetchable(UPGRADE, H_CLOTH), 0, "and the hall cannot take it back")
	_check(v, "reserved three ways", 9000)


func test_a_treatment_cancellation_and_loads_in_transit_conserve_the_cloth() -> void:
	"""Treatment, cancel with a load in arms, a load carried back and a cancel after work: the books add up each step."""
	var v := Village.new()
	v.hall.plan_upgrade()
	v.infirmary.plan_at(Vector2.ZERO, 0.0)
	v.care.hurt(0, Injury.KIND_CUT, Injury.SEVERITY_MINOR, 5)
	assert_true(v.care.claim_cloth(0), "the healer sent: its cloth reserved")
	var in_arms: int = v.hall.lift(UPGRADE, H_CLOTH, v.hall.reserve(UPGRADE, H_CLOTH, 8000))
	assert_equal(in_arms, 8000, "the hall's cloth in a carrier's arms")
	_check(v, "hall cloth in transit")
	var inf_arms: int = v.infirmary.lift(I_CLOTH, v.infirmary.reserve(I_CLOTH, 12000))
	assert_equal(inf_arms, 12000, "the infirmary's in arms too")
	assert_equal(v.stores.cloth_milli_u, 4000, "4 U left in the stores")
	assert_equal(v.care.pay_treatment(0), CareState.REFUSE_NONE, "the treatment starts: its reserved cloth is lifted")
	assert_equal(v.stores.cloth_milli_u, 3500, "3.5 U left")
	_check(v, "treatment paid")
	v.infirmary.return_load(I_CLOTH, 5000)
	assert_equal(v.stores.cloth_milli_u, 8500, "a carrier called away puts 5 U back")
	_check(v, "a load carried back")
	assert_equal(v.hall.cancel(UPGRADE), "", "the upgrade cancelled with its load in arms")
	assert_equal(v.stores.cloth_milli_u, 16500, "the load comes back whole")
	assert_equal(v.stores.cloth_claim(StoresScript.CLOTH_HALL), 0, "and the hall holds no claim")
	_check(v, "hall cancelled")


func test_a_cancel_after_work_loses_the_fifth_and_releases_reservations() -> void:
	"""REQ-SET-126: cancelled after work began, 80% of the delivered cloth comes back (the rest is lost), and a cancel
	gives back any cloth still reserved."""
	var v := Village.new()
	v.infirmary.plan_at(Vector2.ZERO, 0.0)
	_fetch_all_cloth(v)
	assert_true(v.infirmary.state == InfProject.STATE_BUILDING, "all delivered: building")
	v.infirmary.add_work(1000)
	assert_equal(v.infirmary.cancel(), "", "cancelled after work began")
	assert_equal(v.stores.cloth_milli_u, OPENING - 12000 + 9600, "80% of 12 U back")
	v.infirmary.plan_at(Vector2.ZERO, 0.0)
	assert_equal(v.infirmary.reserve(I_CLOTH, 12000), 12000, "the infirmary placed again reserves 12 U")
	assert_equal(v.infirmary.cancel(), "", "cancelled with its reservation still held")
	assert_equal(v.stores.cloth_claim(StoresScript.CLOTH_INFIRMARY), 0, "the cancel gave the infirmary's back")
	v.hall.plan_upgrade()
	v.hall.reserve(UPGRADE, H_CLOTH, 8000)
	assert_equal(v.stores.cloth_claim(StoresScript.CLOTH_HALL), 8000, "8 U reserved for the hall")
	v.hall.cancel(UPGRADE)
	assert_equal(v.stores.cloth_claim(StoresScript.CLOTH_HALL), 0, "the cancel gave the reservation back")
	assert_equal(v.stores.cloth_free(), v.stores.cloth_milli_u, "all of it free again")


func test_an_unpaid_treatment_s_reservation_is_given_back() -> void:
	"""A healer stopped before work: the treatment's reservation goes back; paid, nothing is given back."""
	var v := Village.new()
	v.care.hurt(1, Injury.KIND_BITE, Injury.SEVERITY_MINOR, 5)
	assert_true(v.care.claim_cloth(1), "reserved")
	assert_true(v.care.claim_cloth(1), "a second claim holds the same half unit")
	assert_equal(v.care.cloth_claim_of(1), TREATMENT_CLOTH, "once")
	assert_equal(v.stores.cloth_free(), OPENING - TREATMENT_CLOTH, "kept from the others")
	v.care.release_cloth(1)
	assert_equal([v.care.cloth_claim_of(1), v.stores.cloth_free()], [0, OPENING], "given back")
	v.care.pay_treatment(1)
	v.care.release_cloth(1)
	assert_equal(v.stores.cloth_milli_u, OPENING - TREATMENT_CLOTH, "paid: taken, and a release gives nothing back")
	assert_equal(v.stores.cloth_claimed(), 0, "no claim left behind")


func test_the_stores_cloth_api_is_all_or_nothing() -> void:
	"""reserve takes what is free; release only what was reserved; take only free cloth, all or nothing; add."""
	var stores := StoresScript.new()
	assert_equal(stores.reserve_cloth(StoresScript.CLOTH_HALL, 30000), OPENING, "no more than there is")
	assert_equal(stores.reserve_cloth(StoresScript.CLOTH_TREATMENT, 1), 0, "nothing free")
	assert_false(stores.take_cloth(1), "reserved cloth is not free to take")
	assert_equal(stores.release_cloth(StoresScript.CLOTH_HALL, 50000), OPENING, "only what it held")
	assert_equal(stores.release_cloth(StoresScript.CLOTH_HALL, 1), 0, "nothing more")
	assert_true(stores.take_cloth(OPENING), "all of it")
	assert_false(stores.take_cloth(1), "none left")
	assert_false(stores.take_cloth(0), "nothing is not a take")
	stores.add_cloth(-5)
	assert_equal(stores.cloth_milli_u, 0, "a negative add is nothing")
	stores.add_cloth(700)
	assert_equal([stores.cloth_milli_u, stores.cloth_free()], [700, 700], "back in")
	assert_equal(stores.reserve_cloth(StoresScript.CLOTH_CLAIMANTS, 1), 0, "no such claimant")
	assert_equal(stores.release_cloth(-1, 1), 0, "no such claimant")
	assert_equal(stores.cloth_claim(StoresScript.CLOTH_CLAIMANTS), 0, "no such claim")


func test_a_paid_treatment_sent_a_healer_again_reserves_nothing_more() -> void:
	"""Review M3: once a treatment is paid its cloth is taken; a healer sent again to it (the first stood down) reserves
	no second half unit, and nothing is left claimed."""
	var v := Village.new()
	v.care.hurt(2, Injury.KIND_CUT, Injury.SEVERITY_MINOR, 5)
	assert_true(v.care.claim_cloth(2), "reserved")
	assert_equal(v.care.pay_treatment(2), CareState.REFUSE_NONE, "paid at work start")
	v.care.release_cloth(2)
	assert_true(v.care.claim_cloth(2), "a healer sent again: it holds its cloth already")
	assert_equal([v.stores.cloth_claimed(), v.stores.cloth_milli_u], [0, OPENING - TREATMENT_CLOTH],
		"no second reservation; taken once")
