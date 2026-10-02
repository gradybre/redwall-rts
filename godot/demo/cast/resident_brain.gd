extends RefCounted
## One demo resident's wandering: which POI next, the route there, walking it, and what to do on
## arrival. Decision 0196. Pure logic -- no nodes -- so the tests drive it without a scene tree; the
## actor node reads `position`, `yaw`, `clip` and `clip_speed` back each frame and draws them.
##
## The cycle:  IDLE -> (pick a POI, plan) -> TURN -> WALK -> FACE -> ACT -> IDLE -> ACT ... -> IDLE -> TURN
##   * TURN   turns on the spot toward the route before setting off, stepping in place (the
##            shuffle) past SHUFFLE_ANGLE. It hands over to WALK as soon as the route is within
##            BLEND_WALK_ANGLE and the ground ahead is clear, so a big turn finishes on a walking
##            curve; only a walker boxed in (facing a wall, say) turns all the way on the spot.
##   * WALK   moves along `yaw` at the creature's walk speed -- the gait speed recorded on its walk
##            clip (decision 0202, tools/stage_demo_assets.py) times the demo's walking pace (decision
##            0205, demo_actor.gd WALK_PACE) -- with the walk clip at walk speed over that gait speed,
##            which is what keeps the pinned planted foot from sliding. The yaw
##            turns toward the route at a limited rate; a demand past STOP_TO_TURN_ANGLE stops the
##            walker and hands back to TURN rather than skating round a tight corner.
##   * ACT    plays the POI's activities in bouts (BOUTS_MIN..MAX of them, each a different activity
##            from the last where there is a choice), and keeps adding bouts until it has worked
##            WORK_PER_WALK times as long as the trip there took.
##   * A trip away from a stockpile may carry: the carry clip plays at clip_root_motion's playback
##            rate for the chosen speed, and each frame's step follows the clip's own recorded root
##            path key by key -- its uneven pace AND its sideways weave (up to +-0.24 m over a loop on
##            the badger) -- so a planted foot stays planted there too (decision 0195).
##
## Getting unstuck, all bounded: someone standing across the current leg -> replan at once; held back
## by the constraint for BLOCKED_AFTER_S, no headway (or turning) for STUCK_AFTER_S, or more than
## MAX_FLIPS walk -> turn flips on one leg -> replan; more than MAX_REPLANS -> give the trip up and
## release the slot.
##
## ORDERS (the demo's select-and-command layer, demo/control/). `order_move()` gives up any POI slot,
## walks to a point and HOLDs there -- idle, facing the way it came, never wandering. `order_work()`
## takes a given free slot at a POI and works there, bout after bout, until released. A trip an order
## cannot finish ends in HOLD where the walker stands, never in wandering. `release()` hands the
## resident back: a holder or an ordered walker stops, idles a moment and wanders on; an ordered
## worker finishes its bout and wanders on from there.
##
## TUNNELS (demo/tunnel/; the network is a graph, decision 0208). A route may go through the network:
## `path_tunnel` holds, per waypoint, how it is reached -- SURFACE_LEG, or a LEG LIST of segments walked
## end to end (tunnel_router.gd LEG CODES), one waypoint per node on the way. The walker must reach the
## mouth itself -- no corner is cut into or past one -- then TUNNEL walks the segments underground at walk
## speed, off the surface (CastSpace.set_underground), on from node to node, and comes up at the far mouth
## to go on. At each node the next segment is checked again (MOVE-REQ-006): closed, or the network split
## since the plan, the rest of the way is found again from there, or the walker goes out at the nearest
## mouth and plans again. Segments entered are always walked out of (MOVE-REQ-007): an order given
## underground is carried out from the mouth it comes up at. A trip may also END at a node underground (a
## dig's start, a job's place): the route's last segment ends there. `order_dig()` walks a digger to a
## segment's start -- a mouth on the surface, or a node inside the network -- and DIGs: the segment's own
## integer clock advances while it works (underground_graph.gd), the digger follows its face and, when it
## opens, digs on into the next segment of its piece; with the piece done it takes up its next piece in
## the job list, or comes up (at the mouth it broke out at, or the nearest), stepping clear of the hole --
## the first of STEP_OUT_TURNS that stays inside the village and clear of obstacles, holes and residents
## -- and holds there. Called away while digging, it leaves the segment paused and backs out through what
## it dug and on out of the network. A digger that cannot REACH the start leaves it paused as a plan
## (underground_graph.hold_unreached), never deleted.
##
## SHARING A BORE. Inside a tunnel a walker keeps BORE_GAP_M behind anyone ahead going its way
## (following, never overlapping), and steps PASS_OFFSET_M to its right while someone comes the
## other way within PASS_WINDOW_M -- two walkers pass side by side inside the one-metre bore. At the
## far mouth it waits below while someone on the surface stands on the hole, for at most
## EMERGE_WAIT_S, rather than coming up into them.
##
## WEATHER AND LANTERNS (demo/weather/, demo/tunnel/). On the surface a walker covers ground at its
## walk speed times the weather's surface speed (underground_graph.surface_permille), its clip slowed
## to match so the feet stay planted; in a bore, at walk speed times the bore's own speed (faster
## when lit), whatever the weather, its clip sped to match -- and slowed with it when it has to
## close up behind someone ahead. The clip's rate is always ground speed over walk speed.
##
## HAULING (demo/tunnel/). A carrier may take a tunnel whose bore fits it WITH its load
## (underground_graph.fits_tunnel, loaded): its trip is planned loaded, it walks the bore at the carry's
## own pace and clip, and only the surface part of its trip counts toward CARRY_MAX_TRIP_M.
##
## QUEUES (tunnel_queue.gd). Heading down a tunnel, a walker within JOIN_M of a busy mouth joins its
## line (QUEUE) instead of crowding it, stands at its place facing the hole, moves up as the line
## does, and walks on once it holds the mouth's grant; after QUEUE_GIVE_UP_S it plans a walk instead.
##
## TASKS (tunnel_task.gd). `order_task()` hands the resident to a task -- a tunnel job, a dig crew's
## place, an evacuation: it walks to the task's site, then the task drives it (TASK) through the
## task_* functions until it is done, and the resident goes back to its routine. A new order or a
## release cancels the task first; one standing in a bore walks out to the nearest mouth. A dig crew's hauler
## (decision 0211) carries its basket out with `task_haul_out`: loaded, through the network to its heap's mouth and
## on to the heap.
##
## THE WATER (demo/waterplay/). A route may also cross one of the water's crossings -- a finished
## bridge, or for a swimmer a link across the stream or the pond (tunnel_router.gd CROSSINGS). The
## walker must reach the crossing's end itself, as a tunnel's mouth; then CROSS hands its movement to
## the space's crossing hook (cast/crossing_hook.gd `step_leg`) until it stands at the far end, and it
## goes on. A crossing entered is always finished (MOVE-REQ-007): an order given on it is carried out
## from the far end. On the ground the hook also gives the height of the carved banks and wading beds
## (`ground_y_m`) and slows the pace in wading water, the clip slowed to match. `interrupt_to_task`
## is the one exception to MOVE-REQ-007, for the water's emergencies only: a swimmer in difficulty is
## taken off its leg where it is, by the rescue (HAZ-002: "retain location/air, mark DISTRESS and
## dispatch rescue"). `in_water` tells the actor to draw it swimming (tail streaming back).
##
## RESUMING (decision 0205). A resident called away from a job it had not finished -- a tunnel job, a
## dig, a farm or a woods job -- keeps it (`remember_unfinished`, cast/unfinished_job.gd), the latest
## RESUME_MAX of them. When the work that took it is done -- a task ends on its own, or a crew's job
## is done (`work_done`) -- it takes up the latest one that still waits for it, and so on back; a job
## done, cancelled or taken by someone else meanwhile is dropped. The player's R (`release`) forgets
## them all: released means back to its own routine.
##
## THE ORDER LIST (decision 0411, review UX-002; UI §3's eight-task queue). The same list holds the player's QUEUED
## orders: Shift+right-click appends one (`append_queued`) to the END of the list -- taken after everything already on
## it -- where a job kept from an interruption goes to the front, taken next. So the list in TAKE ORDER (`queue_*`,
## index 0 next) reads Now -> Next ... -> then back to its routine. At most QUEUE_MAX queued orders (UI §3's eight
## manual tasks) and, apart from them, at most RESUME_MAX jobs kept from interruptions (the oldest of those goes) -- so
## a full queue never pushes out the job an interruption left, nor an interruption the player's queue. The player may
## remove an entry or move it up or down. Nothing else is a queue: every entry is taken up by the one path above
## (`take_up_unfinished`); one handed its task some other way is forgotten (`forget_task`).
##
## THE NIGHT (decision 0210, demo/burrow/night_routine.gd). At dusk the night routine hands each resident a sleep
## task (sleep_task.gd): home through the network to its own bed, lie down, sleep, and in the morning up and back to
## the job it parked (RESUMING). While it is night `resting` is set, so the crews' routine pick-ups pass it by; a task
## lays the body down with `task_lie` (`lying`, `lie_top_y_m`: the actor seats it there by its lowest point) and
## stands it up with `task_rise`, strolls it about a room's floor with `task_stroll_to`, and puts it inside a
## building with `task_go_indoors` (the actor is not drawn). A carrier may also be ordered DOWN to a node
## (`order_carry_below`, a root cellar's middle): it walks in loaded, holds there below, and walks out when
## released or ordered on.
##
## RAMPS (decision 0207). A mouth's ramp falls at up to 1:2.5 (tunnel_rules.gd). Walking it, the pace
## is measured along the SLOPE -- the route's flat distance is stepped at walk speed times its cosine --
## so the clip, playing at the stride rate, keeps the feet on it; and `pitch` tilts the body with the
## slope (the actor leans the spine half of it back).
##
## ARRIVAL AND REFUSAL (decision 0361, the review's F02/F05). How the current trip ended is explicit: `trip_outcome` is
## TRIP_UNDERWAY from the moment a trip is started, TRIP_ARRIVED only in `_arrive()` -- at its goal -- and TRIP_FAILED
## when it is given up (`_abandon_trip`). Holding is no evidence of arrival: a walker that gave a trip up holds too, its
## goal unchanged. A job's owner asks `arrived_near(spot, reach)` -- arrived AND standing within reach of the spot it
## reserved -- before it credits any work there. A route that does not exist at all (an empty plan: a node below cut
## off, a refusal of every way in) is never walked: `_begin_leg` refuses it and the trip is given up at once, the job
## suspended (kept to come back to) and its reservations released. Either way `route_refusal()` says why, in words the
## party panel shows beside "holding".
##
## ROUTING (decision 0361, the review's F06). Planning costs real time (a group order through the village ran 5-26 ms),
## so trip starts go through the space's routing desk (route_desk.gd): an order, a task's walk or a replan plans at
## once while the frame's routing budget lasts, else the resident stands in ROUTE -- "finding a route" in the party
## panel -- until its turn comes, first come first served, on a later frame (DemoCast serves the desk each frame). A
## routine departure that finds the budget spent just idles a moment longer. Out of the live scene the desk has no
## budget and every plan runs at once.
##
## Yaw 0 faces +Z, the way the models face: forward is Vector2(sin(yaw), cos(yaw)) in (x, z).
## Deterministic: every random choice comes from this resident's own seeded generator. (In the live scene the FRAME a
## trip sets off on can depend on how long route planning takes on the machine -- see ROUTING -- never where it goes.)

const ClipRootMotionScript := preload("res://scripts/presentation/clip_root_motion.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastRoutinesScript := preload("res://demo/cast/cast_routines.gd")
const TunnelRouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const TunnelQueueScript := preload("res://demo/tunnel/tunnel_queue.gd")
const TaskScript := preload("res://demo/tunnel/tunnel_task.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const GraphPathsScript := preload("res://demo/tunnel/graph_paths.gd")
const LayersScript := preload("res://demo/demo_layers.gd")

enum State { IDLE, TURN, WALK, FACE, ACT, HOLD, TUNNEL, DIG, QUEUE, TASK, CROSS, ROUTE }

const ORDER_NONE: int = 0
const ORDER_MOVE: int = 1
const ORDER_WORK: int = 2
const ORDER_DIG: int = 3
const ORDER_TASK: int = 4

## What the command layer shows a resident doing (activity()).
const ACTIVITY_WANDERING: int = 0
const ACTIVITY_WALKING: int = 1
const ACTIVITY_WORKING: int = 2
const ACTIVITY_HOLDING: int = 3
const ACTIVITY_TUNNEL: int = 4
const ACTIVITY_DIGGING: int = 5
const ACTIVITY_TASK: int = 6
const ACTIVITY_QUEUE: int = 7
const ACTIVITY_CROSSING: int = 8
const ACTIVITY_ROUTING: int = 9

## How the current trip ended (see ARRIVAL AND REFUSAL).
const TRIP_UNDERWAY: int = 0
const TRIP_ARRIVED: int = 1
const TRIP_FAILED: int = 2
## Why a trip was given up (see ARRIVAL AND REFUSAL).
const REFUSED_NO_ROUTE: String = "can't find a way there"
const REFUSED_BLOCKED: String = "gave up: the way there stayed blocked"
## A routine departure that finds the frame's routing budget spent idles this long before it tries again (see ROUTING).
const ROUTE_RETRY_S: float = 0.2

const CLIP_IDLE: StringName = &"idle"
const CLIP_WALK: StringName = &"walk"
const CLIP_CARRY: StringName = &"carry_heavy_object_walk"
## Asleep in bed (Meshy's Sleep_Normally, decision 0204; staged as sleep_normally, decision 0210).
const CLIP_SLEEP: StringName = &"sleep_normally"
## Digging plays the first of these the creature has: pulling up from the ground, else collecting.
const DIG_CLIPS: Array[StringName] = [&"pull_radish", &"collect_object"]
## Out of a finished tunnel, the digger steps this far on (demo) so the exit is left clear, when the
## ground there keeps this much clear of every obstacle beyond its body.
const STEP_OUT_M: float = 1.0
const STEP_OUT_CLEAR_M: float = 0.12
## The step-out directions tried in order, as turns (radians) from straight on out of the exit.
const STEP_OUT_TURNS: Array[float] = [0.0, 0.785398, -0.785398, 1.570796, -1.570796, 2.356194, -2.356194]
## Sharing a bore (see SHARING A BORE); demo values.
const BORE_GAP_M: float = 0.15
const PASS_OFFSET_M: float = 0.25
const PASS_WINDOW_M: float = 1.6
const SIDE_STEP_M_S: float = 0.6
const EMERGE_WAIT_S: float = 6.0
const EMERGE_CLEAR_M: float = 0.05
## Waiting in a mouth's line (see QUEUES): give up after this, and shuffle up within this of a place.
const QUEUE_GIVE_UP_S: float = 25.0
const QUEUE_PLACE_M: float = 0.06

const WALK_TURN_RATE: float = 1.75          ## rad/s while walking (~100 deg/s)
const SPOT_TURN_RATE: float = 3.2           ## rad/s turning on the spot (~185 deg/s)
const STOP_TO_TURN_ANGLE: float = 1.31      ## ~75 deg: stop and turn on the spot instead
const START_WALK_ANGLE: float = 0.21        ## ~12 deg: close enough to set off whatever is ahead
const BLEND_WALK_ANGLE: float = 1.05        ## ~60 deg: set off and finish the turn walking, if clear
const BLEND_CLEAR_M: float = 0.7            ## how far ahead must be clear to finish a turn walking
const FACE_DONE_ANGLE: float = 0.035        ## ~2 deg
const SHUFFLE_ANGLE: float = 0.79           ## ~45 deg: a turn this big steps in place
const SHUFFLE_CLIP_SPEED: float = 0.75
const WAYPOINT_REACH_M: float = 0.3
const ARRIVE_RADIUS_M: float = 0.12
## A task's site on the ground that another resident stands on (two of a dig crew sent to one mouth, decision 0211):
## stuck within this of it, the walker has arrived -- the dig crew enters from this near (tunnel_crew_task.gd).
const CROWDED_SITE_M: float = 0.35
const SEPARATION_WEIGHT: float = 1.2
const STUCK_AFTER_S: float = 2.5
const BLOCKED_AFTER_S: float = 0.35         ## held back this long by someone -> plan round them
const BLOCKED_FRACTION: float = 0.3         ## a frame moving less than this share of its step is held back
const STANDING_TOLERANCE_M: float = 0.08    ## how deep a leg may graze someone standing before replanning
const STUCK_PROGRESS_M: float = 0.05
const MAX_REPLANS: int = 4
const MAX_FLIPS: int = 4                    ## walk -> stop-and-turn flips on one leg before replanning
const IDLE_MIN_S: float = 1.2
const IDLE_MAX_S: float = 3.2
const ACT_MIN_S: float = 8.0
const ACT_MAX_S: float = 20.0
## A walker slower than SLOW_WALK_M_S works proportionally longer (up to SLOW_WORK_MAX times), so
## the mole's day is not mostly walking.
const SLOW_WALK_M_S: float = 0.75
const SLOW_WORK_MAX: float = 1.6
const BOUTS_MIN: int = 1
const BOUTS_MAX: int = 3
## A wandering resident works at a POI at least this many times as long as it spent walking and
## turning to get there, adding bouts until it has -- so no one's day is mostly walking, whatever
## its speed or however far its homes lie apart (walking stays under 1 / (1 + WORK_PER_WALK)).
const WORK_PER_WALK: float = 2.0
const RETRY_S: float = 1.5
const CARRY_CHANCE: float = 0.5
## A carry walks at CARRY_WALK_FRACTION of walk speed (decision 0205: the playtest's mole was "way too
## slow with a log" at the old 0.37), its clip sped to that pace over the clip's own recorded root speed
## -- the carry clips' strides are about half a walk's, so at 0.65 they step a little quicker than a
## walk, short and hurried under the load. The rate stays within [CARRY_MIN_RATE, CARRY_MAX_RATE] of the
## clip's own pace; every staged creature's lands inside it (3.0 to 4.0). Routine carries stay short
## trips; an ordered one goes as far as it must.
const CARRY_MAX_TRIP_M: float = 8.0
const CARRY_WALK_FRACTION: float = 0.65
const CARRY_MIN_RATE: float = 1.0
const CARRY_MAX_RATE: float = 4.2
const DEFAULT_CLIP_S: float = 3.0
## How many unfinished jobs a resident keeps to come back to (see RESUMING; demo value, 0205).
const RESUME_MAX: int = 3
## How many queued orders its order list holds (see THE ORDER LIST; UI §3: "Append up to 8 manual tasks per resident").
const QUEUE_MAX: int = 8

var index: int = -1
var position: Vector2 = Vector2.ZERO
var yaw: float = 0.0
var state: State = State.IDLE
var clip: StringName = CLIP_IDLE
var clip_speed: float = 1.0
var walk_speed: float = 0.8
## The walk clip's own recorded gait speed (decision 0202), m/s; 0 when it is walk_speed itself.
var gait_speed: float = 0.0
var radius: float = 0.25
var poi: int = -1
var slot: int = -1
var carrying: bool = false
## ORDER_NONE while wandering on its own; ORDER_MOVE / ORDER_WORK while under a player's order.
var order: int = ORDER_NONE
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## This resident's routine (cast_routines.gd): its home POIs and the village's social ones. Empty
## homes means "anywhere, nearer preferred".
var homes: PackedInt32Array = PackedInt32Array()
var socials: PackedInt32Array = PackedInt32Array()
## Per waypoint of `path`: the tunnel leg crossed to reach it, or SURFACE_LEG (see TUNNELS).
var path_tunnel: PackedInt32Array = PackedInt32Array()
## Inside a tunnel, and how far below the ground its feet are (presentation: 0 on the surface).
var underground: bool = false
var ground_y_m: float = 0.0
## Presentation: the body's tilt with a ramp's slope (radians, positive nose down; see RAMPS).
var pitch: float = 0.0
## The tunnel this resident is ordered to dig, as an EntityRef (slot, generation); null (-1, 0).
var dig_tunnel: int = -1
var dig_generation: int = 0
## The task driving this resident under ORDER_TASK (null otherwise).
var task: TaskScript = null
## In the water (swimming, diving, towed) -- presentation: the actor draws the tail streaming back.
var in_water: bool = false
## Held by the water's rescue (in difficulty, or being towed): orders and releases are not taken.
var water_hold: bool = false
## THE NIGHT (see above): night, and its routine is to sleep; lying down, on what (the top of a mattress, or a floor,
## m); indoors (not drawn); and where the lying body's middle is from its root, in its own frame (x, z m; the staged
## sleep clip's measure, set by the actor).
var resting: bool = false
var lying: bool = false
var lie_top_y_m: float = 0.0
var indoors: bool = false
var lie_middle_m: Vector2 = Vector2.ZERO
## ITS WORK PACE: how much of its work it does, per mille -- the village's one work pace (demo/work/work_pace.gd: the
## winter's Chilled factor times the infirmary's health factor), which the winter writes here each frame (decision 0902;
## decisions 0571, 0622). The outdoor crews credit their work through `work_credit`; the infirmary's heal work reads the
## pace itself, so nothing applies it twice.
var work_permille: int = 1000
## The work's sub-microsecond remainder at a reduced rate (per mille x usec), so a slowed job loses nothing.
var _work_remainder: int = 0
## The unfinished jobs it will come back to, oldest first (see RESUMING).
var _unfinished: Array[UnfinishedScript] = []
## Bumped whenever its order list changes (an entry kept, queued, taken up, removed or moved; see THE ORDER LIST).
var queue_revision: int = 0
## How the current trip ended: TRIP_* (see ARRIVAL AND REFUSAL).
var trip_outcome: int = TRIP_ARRIVED

var _space: CastSpaceScript = null
var _clip_lengths: Dictionary = {}
var _timer: float = 0.0
var _bouts_left: int = 0
var _turn_clip: StringName = CLIP_IDLE
var _turn_clip_speed: float = 1.0
var _clip_time: float = 0.0
var _goal: Vector2 = Vector2.ZERO
var _best_distance: float = INF
var _stuck_time: float = 0.0
var _blocked_time: float = 0.0
var _replans: int = 0
var _flips: int = 0
var _last_activity: StringName = &""
## Seconds spent turning and walking on the current trip, and working since arriving (WORK_PER_WALK).
var _trip_s: float = 0.0
var _worked_s: float = 0.0
## Where an ordered holder turns to face on arrival, when _faces_on_hold (else it keeps facing the
## way it came).
var _hold_face: Vector2 = Vector2.ZERO
var _faces_on_hold: bool = false
var _carry_velocity: PackedVector2Array = PackedVector2Array()
var _carry_key_s: float = 1.0
var _carry_rate: float = 1.0
## Walking a tunnel: which, from where to where along it (metres), and whether toward the dig face.
var _travel_slot: int = 0
var _travel_m: float = 0.0
var _travel_end_m: float = 0.0
var _travel_forward: bool = true
## Scratch for a sample of a bore's drawn centreline (point, heading).
var _curve_sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _travel_to_face: bool = false
## Released while underground: idle once up, rather than going on.
var _idle_on_surface: bool = false
## A task ended underground: take up the latest unfinished job once up (see RESUMING).
var _resume_on_surface: bool = false
## Inside a bore: how far it has stepped to its right to let someone pass, and how long it has waited
## at the far mouth for the hole to clear.
var _side_m: float = 0.0
var _emerge_waited: float = 0.0
## The carry's own pace (m/s at its playback rate), walked in a bore while carrying.
var _carry_speed: float = 0.0
## Waiting in a line: which mouth (its row) and for how long; whether it holds a grant.
var _queue_mouth: int = 0
var _queue_waited: float = 0.0
var _holds_grant: bool = false
var _travel_start_m: float = 0.0
## A task's walk in a bore: at its end the task resumes, still underground.
var _travel_for_task: bool = false
## The node underground the trip is bound for (-1: a goal on the surface), and the network's topology the
## route was planned on (a split since means the route is found again at the next node).
var _goal_node: int = -1
var _route_topology: int = -1
## Stranded underground with every way out closed: seconds waited (-1: not stranded).
var _stranded_s: float = -1.0
## Up out of a hole after a dig: step clear of it before holding.
var _step_out_on_surface: bool = false
## Scratch: the segments of a walk through the network.
var _segments: PackedInt32Array = PackedInt32Array()
## Why the last trip was given up ("" when it was not; see ARRIVAL AND REFUSAL).
var _refusal: String = ""
## A dig's piece done and the digger stepping clear of the hole: once it holds, it takes up its saved job (RESUMING).
var _resume_after_dig: bool = false
## Waiting at the routing desk (see ROUTING): how the trip it waits for is planned -- through tunnels, loaded -- and
## whether it then sets off carrying (an ordered carry), as `order_carry` and `order_carry_below` start one.
var _route_tunnels: bool = true
var _route_loaded: bool = false
var _route_carry: bool = false
## Set while `order_carry` (or `order_carry_below`) starts its trip: the trip sets off carrying.
var _carry_order: bool = false


func configure(cast_space: CastSpaceScript, speed_m_s: float, body_radius: float, seed_value: int, clip_lengths: Dictionary) -> void:
	"""Join `cast_space` as a new resident. `clip_lengths` maps each playable clip to its length in seconds."""
	_space = cast_space
	walk_speed = speed_m_s
	radius = body_radius
	rng.seed = seed_value
	_clip_lengths = clip_lengths
	index = cast_space.add_resident(position, radius)
	cast_space.routes.register(index, route_turn)


func space() -> CastSpaceScript:
	"""The space this resident walks in (its POIs, obstacles and the network)."""
	return _space


func set_gait_speed(speed_m_s: float) -> void:
	"""The walk clip's recorded gait speed, when this resident walks faster (or slower) than it: the walk
	clip then plays at walk_speed over it, so the pinned feet keep their ground (decision 0205)."""
	gait_speed = maxf(speed_m_s, 0.0)


func gait_rate() -> float:
	"""The walk clip's rate at walk speed: walk_speed over the clip's gait speed (1 without one)."""
	return walk_speed / gait_speed if gait_speed > ClipRootMotionScript.MIN_SPEED_M_S else 1.0


func stride_rate() -> float:
	"""The locomotion clip's rate at this resident's own pace, before weather, bore or wading: the carry's
	with a load, else the walk's (gait_rate)."""
	return _carry_rate if carrying else gait_rate()


func set_carry_motion(motion: Dictionary) -> void:
	"""The carry clip's recorded root motion (clip_root_motion.read). Without it, nobody carries."""
	var keys: Array = motion.get("keys_xz", [])
	var mean := float(motion.get("mean_speed_m_s", 0.0))
	var period := float(motion.get("period_s", 0.0))
	if keys.size() < 2 or mean < ClipRootMotionScript.MIN_SPEED_M_S or period <= 0.0 or not has_clip(CLIP_CARRY):
		return
	_carry_key_s = period / float(keys.size() - 1)
	_carry_velocity.resize(keys.size() - 1)
	for k in keys.size() - 1:
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		_carry_velocity[k] = Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1])) / _carry_key_s
	var carry_speed := clampf(walk_speed * CARRY_WALK_FRACTION, mean * CARRY_MIN_RATE, mean * CARRY_MAX_RATE)
	_carry_rate = ClipRootMotionScript.playback_rate(motion, carry_speed)
	_carry_speed = carry_speed


func trip_seconds() -> float:
	"""Seconds spent turning, walking and in tunnels on the current trip (what WORK_PER_WALK weighs)."""
	return _trip_s


func clip_time() -> float:
	"""Seconds of clip played since the current clip began (at its playback speed)."""
	return _clip_time


func can_carry() -> bool:
	"""Whether this resident has a carry clip with recorded root motion."""
	return not _carry_velocity.is_empty()


func has_clip(name: StringName) -> bool:
	"""Whether `name` is one of this resident's clips."""
	return _clip_lengths.has(name)


func start_at(at: Vector2, face_yaw: float, start_poi: int, start_slot: int) -> void:
	"""Stand at `at` facing `face_yaw`, holding `start_poi`'s slot, and idle a staggered moment first."""
	position = at
	yaw = face_yaw
	poi = start_poi
	slot = start_slot
	_space.move_resident(index, at)
	_bouts_left = rng.randi_range(1, 2) if poi >= 0 else 0
	_enter_idle(rng.randf_range(0.2, IDLE_MAX_S))


func step(delta: float) -> void:
	"""Advance this resident by `delta` seconds."""
	_clip_time += delta * clip_speed
	match state:
		State.IDLE:
			_step_idle(delta)
		State.TURN:
			_step_turn(delta)
		State.WALK:
			_step_walk(delta)
		State.FACE:
			_step_face(delta)
		State.ACT:
			_step_act(delta)
		State.HOLD, State.ROUTE:
			pass
		State.TUNNEL:
			_step_tunnel(delta)
		State.DIG:
			_step_dig(delta)
		State.QUEUE:
			_step_queue(delta)
		State.TASK:
			_step_task(delta)
		State.CROSS:
			_step_cross(delta)
	if state == State.TURN or state == State.WALK or state == State.TUNNEL or state == State.CROSS:
		_trip_s += delta
	_space.set_walking(index, state == State.WALK)


func forward() -> Vector2:
	"""The unit direction this resident faces, in (x, z)."""
	return Vector2(sin(yaw), cos(yaw))


static func yaw_of(direction: Vector2) -> float:
	"""The yaw that faces `direction` (x, z)."""
	return atan2(direction.x, direction.y)


static func turn_toward(from_yaw: float, to_yaw: float, max_step: float) -> float:
	"""`from_yaw` turned the short way toward `to_yaw` by at most `max_step` radians."""
	return from_yaw + clampf(angle_difference(from_yaw, to_yaw), -max_step, max_step)


# --- states ---------------------------------------------------------------------------------

func _set_clip(name: StringName, speed: float) -> void:
	"""Ask for a clip; its clock restarts only when the clip itself changes."""
	if name != clip:
		_clip_time = 0.0
	clip = name
	clip_speed = speed


func _enter_idle(seconds: float) -> void:
	"""Stand and idle for `seconds`."""
	state = State.IDLE
	_timer = seconds
	_set_clip(CLIP_IDLE, 1.0)


func _step_idle(delta: float) -> void:
	"""Idle out the timer, then either another activity bout here or a trip elsewhere."""
	_timer -= delta
	if _timer > 0.0:
		return
	if poi >= 0 and (_bouts_left > 0 or order == ORDER_WORK or owes_work()):
		_bouts_left = maxi(_bouts_left, 1)
		_enter_act()
	elif order != ORDER_NONE:
		_enter_hold()
	else:
		_depart()


func _enter_act() -> void:
	"""Play one of this POI's activities for a whole number of its loops, about ACT_MIN..MAX seconds."""
	state = State.ACT
	_bouts_left -= 1
	var act_clip := _pick_activity(_last_activity)
	_last_activity = act_clip
	var length := float(_clip_lengths.get(act_clip, DEFAULT_CLIP_S))
	var seconds := rng.randf_range(ACT_MIN_S, ACT_MAX_S) * clampf(SLOW_WALK_M_S / walk_speed, 1.0, SLOW_WORK_MAX)
	var loops := maxi(1, roundi(seconds / maxf(length, 0.1)))
	_timer = length * loops
	_set_clip(act_clip, 1.0)


func owes_work() -> bool:
	"""Whether a wandering resident has not yet worked WORK_PER_WALK times its last trip here."""
	return order == ORDER_NONE and _worked_s < WORK_PER_WALK * _trip_s


func _pick_activity(last: StringName) -> StringName:
	"""A random one of the POI's activities this resident can play -- a different one from `last` when
	there is a choice, so bouts cycle -- else idle."""
	var activities := _space.poi_activities[poi]
	var playable := 0
	for act_clip in activities:
		if has_clip(act_clip) and act_clip != last:
			playable += 1
	if playable == 0:
		return last if has_clip(last) and activities.has(last) else CLIP_IDLE
	var pick := rng.randi_range(0, playable - 1)
	for act_clip in activities:
		if has_clip(act_clip) and act_clip != last:
			if pick == 0:
				return act_clip
			pick -= 1
	return CLIP_IDLE


func _step_act(delta: float) -> void:
	"""Hold the activity until its loops are done, then idle between bouts."""
	_timer -= delta
	_worked_s += delta
	if _timer <= 0.0:
		_enter_idle(rng.randf_range(IDLE_MIN_S, IDLE_MAX_S))


func _depart() -> void:
	"""Pick the next POI with room, plan the route, swap reservations and start turning toward it. When
	no route exists -- someone standing across the only way out of a tight slot -- it stays put and
	tries again after RETRY_S, rather than walking the planner's straight-line fallback into a wall."""
	if _routing_spent():
		return
	var next := _choose_next()
	if next < 0:
		_enter_idle(RETRY_S)
		return
	var next_slot := _space.free_slot(next)
	_goal = _space.slot_position(next, next_slot)
	_goal_node = -1
	_plan_trip(true, false)
	if not _space.nav.last_found:
		_enter_idle(RETRY_S)  # boxed in by residents standing across every way out: wait, then retry
		return
	_space.reserve(next, next_slot)
	var leaving_stockpile := poi >= 0 and _space.poi_stockpile[poi] == 1
	_space.release(poi, slot)
	poi = next
	slot = next_slot
	_goal = _space.slot_position(next, next_slot)
	carrying = leaving_stockpile and can_carry() and _surface_length() <= CARRY_MAX_TRIP_M \
			and rng.randf() < CARRY_CHANCE
	if carrying and crosses_tunnel():
		_plan_loaded(CARRY_MAX_TRIP_M)
	_replans = 0
	_trip_s = 0.0
	_start_trip_record()
	_begin_leg()


func _routing_spent() -> bool:
	"""A routine departure finding the frame's routing budget spent (see ROUTING) idles a moment longer instead."""
	if _space.routes.may_plan(index):
		return false
	_enter_idle(ROUTE_RETRY_S)
	return true


func _plan_loaded(max_surface_m: float) -> void:
	"""A carrier's trip crossing a tunnel: plan it again with the load, so only bores that fit the
	load are taken (see HAULING). With no loaded route, or more than `max_surface_m` of it on the
	surface, it goes unloaded on the first plan. (The routine's carries and the farm's ordered carries
	both come through here: one hauling rule.)"""
	var legs := path_tunnel.duplicate()
	var route := path.duplicate()
	_plan_trip(true, true)
	if _space.nav.last_found and _surface_length() <= max_surface_m:
		return
	carrying = false
	path = route
	path_tunnel = legs


func _choose_next() -> int:
	"""The next POI: usually one of the homes, sometimes a social spot, nearer ones preferred."""
	if homes.is_empty():
		return _space.choose_poi_from(homes, poi, position, rng)
	var social := not socials.is_empty() and rng.randf() < CastRoutinesScript.SOCIAL_CHANCE
	var next := _space.choose_poi_from(socials if social else homes, poi, position, rng)
	if next < 0:
		next = _space.choose_poi_from(homes if social else socials, poi, position, rng)
	return next if next >= 0 else _space.choose_poi_from(PackedInt32Array(), poi, position, rng)


func _trip_length() -> float:
	"""Length of the planned route from here."""
	var total := 0.0
	var at := position
	for point in path:
		total += at.distance_to(point)
		at = point
	return total


func _surface_length() -> float:
	"""Length of the planned route from here that lies on the surface (tunnel legs excluded)."""
	var total := 0.0
	var at := position
	for k in path.size():
		if _leg(k) == TunnelRouterScript.SURFACE_LEG:
			total += at.distance_to(path[k])
		at = path[k]
	return total


func _begin_leg() -> void:
	"""Start following `path` from its first waypoint: turn on the spot first -- or, standing at a
	tunnel's mouth already, go straight down it. An empty route -- no way at all -- is never walked: the trip
	is given up, saying why (see ARRIVAL AND REFUSAL)."""
	if path.is_empty():
		_route_failed()
		return
	_leave_line()
	path_index = 0
	_flips = 0
	_reset_progress()
	while path_index < path.size() - 1 and _leg(path_index + 1) != TunnelRouterScript.SURFACE_LEG \
			and position.distance_to(path[path_index]) < WAYPOINT_REACH_M:
		path_index += 1
	if _leg(path_index) != TunnelRouterScript.SURFACE_LEG:
		_enter_tunnel_leg()
		return
	_enter_turn(yaw_of(path[path_index] - position), _locomotion_clip())


func _locomotion_clip() -> StringName:
	"""The clip this trip walks with."""
	return CLIP_CARRY if carrying else CLIP_WALK


func _enter_turn(target_yaw: float, shuffle_clip: StringName) -> void:
	"""Turn on the spot; a big turn steps in place with `shuffle_clip`, a small one stands idle."""
	state = State.TURN
	var big := absf(angle_difference(yaw, target_yaw)) > SHUFFLE_ANGLE
	_turn_clip = shuffle_clip if big else CLIP_IDLE
	_turn_clip_speed = SHUFFLE_CLIP_SPEED if big else 1.0
	if shuffle_clip == CLIP_CARRY and big:
		_turn_clip_speed = SHUFFLE_CLIP_SPEED * _carry_rate
	_set_clip(_turn_clip, _turn_clip_speed)


func _step_turn(delta: float) -> void:
	"""Turn toward the current waypoint; set off once facing it. Time spent turning counts toward
	being stuck, so a walker flipping between walking and turning cannot stall for ever."""
	_stuck_time += delta
	if _stuck_time >= STUCK_AFTER_S:
		_replan_or_abandon()
		return
	var target_yaw := yaw_of(path[path_index] - position)
	yaw = turn_toward(yaw, target_yaw, SPOT_TURN_RATE * delta)
	var error := absf(angle_difference(yaw, target_yaw))
	if error <= START_WALK_ANGLE or (error <= BLEND_WALK_ANGLE and _clear_ahead()):
		state = State.WALK
		_set_clip(_locomotion_clip(), _walk_clip_speed())


func _face_hold(delta: float) -> void:
	"""An ordered holder turning to face its point, then holding."""
	var target_yaw := yaw_of(_hold_face - position)
	yaw = turn_toward(yaw, target_yaw, SPOT_TURN_RATE * delta)
	if absf(angle_difference(yaw, target_yaw)) <= FACE_DONE_ANGLE:
		_enter_hold()


func _clear_ahead() -> bool:
	"""Whether the next BLEND_CLEAR_M straight ahead is clear of obstacles and standing residents."""
	return _space.line_clear(index, position, position + forward() * BLEND_CLEAR_M, radius, _goal)


func _step_face(delta: float) -> void:
	"""Turn to the POI's face direction, then start working -- or, holding, toward _hold_face."""
	if poi < 0:
		_face_hold(delta)
		return
	var face := _space.poi_face[poi]
	if face == Vector2.ZERO:
		_enter_act()
		return
	var target_yaw := yaw_of(face)
	yaw = turn_toward(yaw, target_yaw, SPOT_TURN_RATE * delta)
	if absf(angle_difference(yaw, target_yaw)) <= FACE_DONE_ANGLE:
		_enter_act()


# --- walking --------------------------------------------------------------------------------

func _step_walk(delta: float) -> void:
	"""Steer toward the route (and away from neighbours) at a limited yaw rate, and step forward. Someone
	who has stopped in the way of the current leg means a new plan round them, straight away."""
	if _leg_handled():
		return
	var to_target := path[path_index] - position
	var distance := to_target.length()
	var stride := ground_step(delta)
	if path_index == path.size() - 1 and distance <= maxf(ARRIVE_RADIUS_M, stride.length()):
		_arrive()
		return
	var facing := forward()
	var desired := to_target / maxf(distance, 1e-6) \
			+ _space.separation(index, position, facing) * SEPARATION_WEIGHT
	var error := angle_difference(yaw, yaw_of(desired))
	if absf(error) > STOP_TO_TURN_ANGLE:
		_flips += 1
		if _flips > MAX_FLIPS:
			_replan_or_abandon()
		else:
			_enter_turn(yaw_of(desired), _locomotion_clip())
		return
	yaw = turn_toward(yaw, yaw + error, WALK_TURN_RATE * delta)
	clip_speed = _walk_clip_speed()
	var moved := _space.constrain(index, position, position + stride, _goal)
	var held := moved.distance_to(position) < stride.length() * BLOCKED_FRACTION
	position = moved
	ground_y_m = _space.crossings.ground_y_m(position)
	_space.move_resident(index, moved)
	_watch_progress(distance, held, delta)


func _leg_handled() -> bool:
	"""Pass the waypoints reached; then at a tunnel's mouth go down it, or with someone standing across
	the leg plan round them. True when either happened, so this frame's walking is done."""
	_advance_waypoint()
	if _leg(path_index) != TunnelRouterScript.SURFACE_LEG:
		_enter_tunnel_leg()
		return true
	if _nearing_mouth() and _wait_for_mouth():
		return true
	if _blocked_by_standing(path[path_index]):
		_replan_or_abandon()
		return true
	return false


func _advance_waypoint() -> void:
	"""Move on past a waypoint as soon as the one after it is in clear sight, or once near it -- but not
	while near would start the next leg through someone standing (the plan's leg began at the
	waypoint itself; cutting the corner could clip them and trigger a needless replan). A tunnel's
	mouth is never cut: it is passed only on reaching it, and nothing past it is skipped to."""
	while path_index < path.size() - 1 and _leg(path_index) == TunnelRouterScript.SURFACE_LEG:
		var next := path[path_index + 1]
		var d := position.distance_to(path[path_index])
		if _leg(path_index + 1) != TunnelRouterScript.SURFACE_LEG:
			if d < WAYPOINT_REACH_M:
				path_index += 1
				_reset_progress()
			return
		var near := d < ARRIVE_RADIUS_M or (d < WAYPOINT_REACH_M and not _blocked_by_standing(next))
		if near or _space.line_clear(index, position, next, radius, _goal):
			path_index += 1
			_reset_progress()
		else:
			return


func _blocked_by_standing(to: Vector2) -> bool:
	"""Whether someone standing still is plainly in the way from here to `to`: their radius plus ours,
	less STANDING_TOLERANCE_M, so a leg the plan passed (at a wider margin) never trips it."""
	return _space.standing_blocks(index, position, to, radius, _goal, -STANDING_TOLERANCE_M)


# --- queues at mouths -----------------------------------------------------------------------

func _leave_line() -> void:
	"""Out of any mouth's line, and any grant given up (a new plan or order starts afresh)."""
	if _holds_grant or state == State.QUEUE:
		_space.tunnels.queue.leave(index)
	_holds_grant = false


func _nearing_mouth() -> bool:
	"""Whether the waypoint ahead is a mouth this walk goes down, within JOIN_M, without its grant (a
	crossing's end has no line)."""
	if path_index >= path.size() - 1 or _leg(path_index + 1) == TunnelRouterScript.SURFACE_LEG:
		return false
	if TunnelRouterScript.is_crossing_code(_leg(path_index + 1)) or _space.tunnels.entry_mouth_of(_leg(path_index + 1)) < 0:
		return false
	return not _holds_grant and position.distance_to(path[path_index]) < TunnelQueueScript.JOIN_M


func _mouth_clear(mouth: int) -> bool:
	"""Whether mouth row `mouth` is clear for this resident to step into."""
	return _space.mouth_clear(index, mouth, TunnelQueueScript.HOLD_M)


func _wait_for_mouth() -> bool:
	"""At a mouth ahead: take its grant and walk on, or join its line (true: this frame is spent
	waiting). A full line sends the walker the long way round, on the surface."""
	var mouth: int = _space.tunnels.entry_mouth_of(_leg(path_index + 1))
	var queue := _space.tunnels.queue
	if queue.may_take(mouth, index, _mouth_clear(mouth)):
		queue.take(mouth, index)
		_holds_grant = true
		return false
	if not queue.join(mouth, index):
		_set_off(false, carrying, false)
		return true
	state = State.QUEUE
	_queue_mouth = mouth
	_queue_waited = 0.0
	return true


func _step_queue(delta: float) -> void:
	"""Wait in a mouth's line: shuffle to its place, facing the hole; walk on holding the grant once at
	the head and the mouth is clear; give up after QUEUE_GIVE_UP_S and walk instead."""
	var queue := _space.tunnels.queue
	_queue_waited += delta
	if queue.may_take(_queue_mouth, index, _mouth_clear(_queue_mouth)):
		queue.take(_queue_mouth, index)
		_holds_grant = true
		state = State.WALK
		_reset_progress()
		_set_clip(_locomotion_clip(), _walk_clip_speed())
		return
	if _queue_waited >= QUEUE_GIVE_UP_S or not queue.is_queued(_queue_mouth, index):
		queue.leave(index)
		_set_off(false, carrying, false)
		return
	_shuffle_to(queue.place(_queue_mouth, queue.position_of(_queue_mouth, index)), delta)


func _shuffle_to(place: Vector2, delta: float) -> void:
	"""Step toward a place in a line (never through anyone); there, stand facing the mouth."""
	var to := place - position
	if to.length() <= QUEUE_PLACE_M:
		_set_clip(CLIP_CARRY if carrying else CLIP_IDLE, 0.0 if carrying else 1.0)
		yaw = turn_toward(yaw, yaw_of(path[path_index] - position), SPOT_TURN_RATE * delta)
		return
	yaw = turn_toward(yaw, yaw_of(to), SPOT_TURN_RATE * delta)
	_set_clip(_locomotion_clip(), _walk_clip_speed())
	var stride := to.limit_length(walk_speed * _surface_factor() * delta)
	position = _space.constrain(index, position, position + stride, place)
	_space.move_resident(index, position)


func ground_step(delta: float) -> Vector2:
	"""This frame's step on the ground: straight ahead at walk speed, or while carrying the clip's own
	recorded root velocity at this key (sideways weave included), sped up by the playback rate."""
	var surface := _surface_factor()
	if not carrying:
		return forward() * (walk_speed * delta * surface)
	var length := float(_clip_lengths.get(CLIP_CARRY, DEFAULT_CLIP_S))
	var key := mini(int(fposmod(_clip_time, length) / _carry_key_s), _carry_velocity.size() - 1)
	var local := _carry_velocity[key] * (_carry_rate * delta * surface)
	return Vector2(cos(yaw), -sin(yaw)) * local.x + forward() * local.y


func _surface_factor() -> float:
	"""The weather's surface walking speed as a fraction of walk speed (see WEATHER AND LANTERNS), and
	slower still wading (see THE WATER)."""
	var wade: int = _space.crossings.wade_permille(index, position)
	return float(_space.tunnels.surface_permille) * float(wade) / float(TunnelRules.PERMILLE * TunnelRules.PERMILLE)


func _walk_clip_speed() -> float:
	"""The walking (or carrying) clip's playback rate on the surface: its ground speed over the clip's
	own (clip_root_motion.playback_rate's rule). The walk's own speed is the gait speed the grounding
	tool recorded on it (decision 0202), so at walk_speed times the weather's factor the clip plays at
	walk_speed over that gait speed times the factor (stride_rate), and the pinned feet stay planted."""
	return stride_rate() * _surface_factor()


func _bore_clip_speed() -> float:
	"""The same in a bore, which the weather does not slow but a lantern speeds (see _bore_speed)."""
	return stride_rate() * float(_space.tunnels.speed_permille(_travel_slot)) / float(TunnelRules.PERMILLE)


func _arrive() -> void:
	"""At the slot: turn to the POI's face direction, and plan one or two bouts of work. At an ordered
	point with no POI, hold instead, facing the way it came. At a dig site, start digging. The trip has
	ARRIVED (see ARRIVAL AND REFUSAL)."""
	carrying = false
	trip_outcome = TRIP_ARRIVED
	if order == ORDER_TASK:
		state = State.TASK
		task.arrived(self)
		return
	if order == ORDER_DIG:
		_begin_dig()
		return
	if poi < 0:
		if underground:
			task_hold_below()
		_hold_here()
		return
	_bouts_left = rng.randi_range(BOUTS_MIN, BOUTS_MAX)
	_last_activity = &""
	_worked_s = 0.0
	var face := _space.poi_face[poi]
	_enter_turn(yaw_of(face) if face != Vector2.ZERO else yaw, CLIP_WALK)
	state = State.FACE  # _enter_turn chose the clip; this turn ends in work, not a walk


func _reset_progress() -> void:
	"""Start measuring progress toward a new waypoint."""
	_best_distance = INF
	_stuck_time = 0.0
	_blocked_time = 0.0


func _watch_progress(distance: float, held: bool, delta: float) -> void:
	"""Replan when held back by someone for BLOCKED_AFTER_S, or when no progress is made for
	STUCK_AFTER_S; give the trip up after MAX_REPLANS."""
	_blocked_time = _blocked_time + delta if held else 0.0
	if distance < _best_distance - STUCK_PROGRESS_M:
		_best_distance = distance
		_stuck_time = 0.0
	else:
		_stuck_time += delta
	if _stuck_time < STUCK_AFTER_S and _blocked_time < BLOCKED_AFTER_S:
		return
	_replan_or_abandon()


func _replan_or_abandon() -> void:
	"""Plan the trip again from here, or give it up after MAX_REPLANS -- or at once when no way is found now (boxed in
	by residents standing across every way: an empty route has no leg to begin). A task's walk stuck within
	CROWDED_SITE_M of its site on the ground has arrived."""
	if order == ORDER_TASK and not underground and path_index == path.size() - 1 \
			and position.distance_to(_goal) <= CROWDED_SITE_M:
		_arrive()
		return
	_replans += 1
	if _replans > MAX_REPLANS:
		_refusal = REFUSED_BLOCKED
		_abandon_trip()
		return
	_set_off(true, carrying, false)


func _abandon_trip() -> void:
	"""Give the slot back and stand a moment before choosing somewhere else -- or, under an order,
	hold right here (a routine task lost on the way -- its bed, a fixture -- is no order: it goes back to its own
	routine). Underground it never stands: it walks out to the nearest mouth. A dig it could not
	walk to is left paused as a plan (underground_graph.hold_unreached), never deleted. The trip has FAILED, and
	says why (see ARRIVAL AND REFUSAL)."""
	trip_outcome = TRIP_FAILED
	if _refusal.is_empty():
		_refusal = REFUSED_BLOCKED
	_leave_dig(true)
	_leave_line()
	var routine := order == ORDER_TASK and task != null and not task.holds_when_lost()
	if order == ORDER_TASK:
		_drop_task()
	_space.release(poi, slot)
	poi = -1
	slot = -1
	carrying = false
	if order != ORDER_NONE:
		order = ORDER_NONE if routine else ORDER_MOVE
	if underground and not in_water:
		_walk_out()
	elif order != ORDER_NONE:
		_hold_here()
	else:
		_enter_idle(RETRY_S)


func _route_failed() -> void:
	"""No route at all -- an empty plan: give the trip up now, saying so (see ARRIVAL AND REFUSAL)."""
	_refusal = REFUSED_NO_ROUTE
	_abandon_trip()


func _start_trip_record() -> void:
	"""A trip starts: under way, with nothing refused yet (see ARRIVAL AND REFUSAL)."""
	trip_outcome = TRIP_UNDERWAY
	_refusal = ""


func is_stranded() -> bool:
	"""Whether it stands underground with every way out closed, looking again every RETRY_S (`_wait_stranded`): the
	route overlay's "no safe exit" (demo/routes/route_reasons.gd, decision 0461)."""
	return _stranded_s >= 0.0


func trip_failed() -> bool:
	"""Whether its last trip was given up (see ARRIVAL AND REFUSAL)."""
	return trip_outcome == TRIP_FAILED


func arrived_near(spot: Vector2, reach_m: float) -> bool:
	"""Whether its last trip ARRIVED and it stands on the surface within `reach_m` of `spot` -- the test a job's owner
	makes before crediting work or a delivery there (see ARRIVAL AND REFUSAL)."""
	return trip_outcome == TRIP_ARRIVED and not underground and position.distance_to(spot) <= reach_m


func route_refusal() -> String:
	"""Why its last trip was given up, in words ("" when it was not)."""
	return _refusal


# --- the routing desk (see ROUTING) ----------------------------------------------------------------

func _set_off(tunnels: bool, loaded: bool, carry: bool) -> void:
	"""Plan the trip to its goal (`tunnels`: through them when quicker; `loaded`: with its load) and start along it --
	now while the frame's routing budget lasts and nobody waits before it, else in ROUTE until its turn (see ROUTING).
	`carry`: an ordered carry, which sets off carrying."""
	_route_tunnels = tunnels
	_route_loaded = loaded
	_route_carry = carry
	if _space.routes.may_plan(index):
		_plan_and_go()
		return
	_leave_line()
	_space.routes.wait(index)
	state = State.ROUTE
	_set_clip(CLIP_IDLE, 1.0)


func route_turn() -> void:
	"""Its turn at the routing desk (DemoCast serves it, first come first served): plan and set off. Taken off the trip
	meanwhile (another order, a release), it gives its place up."""
	if state != State.ROUTE:
		_space.routes.forget(index)
		return
	_plan_and_go()


func _plan_and_go() -> void:
	"""Plan the waiting trip and set off along it; an ordered carry sets off carrying, its route planned again LOADED
	when it goes through a tunnel (HAULING)."""
	var carry := _route_carry
	_route_carry = false
	_plan_trip(_route_tunnels, _route_loaded)
	_begin_leg()
	if not carry:
		return
	carrying = can_carry() and not underground and (state == State.TURN or state == State.WALK)
	if carrying and crosses_tunnel():
		_plan_loaded(INF)
		_begin_leg()


# --- orders ---------------------------------------------------------------------------------

func order_move(goal_at: Vector2, face_toward: Vector2 = Vector2.INF) -> void:
	"""Give up any POI slot, walk to `goal_at` and hold there until ordered again or released. Given a
	finite `face_toward`, it turns to face that point on arrival (a queue facing its POI). Not taken
	while the water's rescue holds it (`water_hold`)."""
	if water_hold:
		return
	release_slot()
	_leave_dig()
	_drop_task()
	order = ORDER_MOVE
	_faces_on_hold = face_toward.is_finite()
	_hold_face = face_toward if _faces_on_hold else Vector2.ZERO
	_start_ordered_trip(goal_at)


func order_work(work_poi: int, work_slot: int) -> void:
	"""Walk to `work_slot` at `work_poi` and work there until released. The caller has checked the
	slot is free (or is this resident's own); any other slot held is given up first. Not taken while
	the water's rescue holds it."""
	if water_hold:
		return
	_leave_dig()
	_drop_task()
	if work_poi != poi or work_slot != slot:
		release_slot()
		_space.reserve(work_poi, work_slot)
		poi = work_poi
		slot = work_slot
	order = ORDER_WORK
	_start_ordered_trip(_space.slot_position(work_poi, work_slot))


func release_slot() -> void:
	"""Give back any POI slot this resident holds."""
	_space.release(poi, slot)
	poi = -1
	slot = -1


func release() -> void:
	"""The player's release: back to wandering, forgetting every unfinished job (see RESUMING)."""
	if water_hold:
		return
	_let_go()
	_unfinished.clear()
	queue_revision += 1


func drop_jobs() -> void:
	"""Forget the task and every unfinished job without acting on either: the actor that owns this brain is being
	freed. An unfinished job holds its owner (the kitchen, the tunnel works) and the owner holds the brains, a cycle no
	reference count breaks, so a freed cast kept every such owner alive past a Restart (decision 0501)."""
	task = null
	_unfinished.clear()


func work_credit(usec: int) -> int:
	"""ITS WORK PACE: the work `usec` microseconds of it at its work rate are worth (all of them at full rate), the
	remainder kept so a slowed job is credited exactly over many frames."""
	if work_permille >= 1000 or usec <= 0:
		_work_remainder = 0
		return usec
	var scaled: int = usec * work_permille + _work_remainder
	_work_remainder = scaled % 1000
	@warning_ignore("integer_division")
	var credited: int = scaled / 1000
	return credited


func work_done() -> void:
	"""A crew's job for this resident is done: take up the latest unfinished job that still waits (see
	RESUMING), else back to wandering as `release` does -- keeping the rest for later. In the water it
	swims ashore first (as `release`), and takes them up when its next work is done."""
	if water_hold:
		return
	if in_water or underground or not take_up_unfinished():
		_let_go()
		_resume_on_surface = underground


func _let_go() -> void:
	"""Back to wandering. Holding or walking under a move order, it stops and idles a moment first;
	working under an order, it finishes the bout in hand."""
	_forget_step_out()
	if order == ORDER_NONE:
		return
	var was_move := order == ORDER_MOVE or state == State.HOLD or order == ORDER_TASK
	_drop_task()
	_leave_line()
	order = ORDER_NONE
	_leave_dig()
	if underground or state == State.CROSS:
		_release_underground(was_move)
		return
	if in_water:
		release_slot()
		_idle_on_surface = true
		_space.crossings.swim_ashore(self)
		return
	if was_move or poi < 0:
		release_slot()
		carrying = false
		_bouts_left = 0
		_enter_idle(rng.randf_range(IDLE_MIN_S * 0.5, IDLE_MIN_S))
	else:
		_bouts_left = mini(_bouts_left, 1)
		_trip_s = 0.0


func _release_underground(was_move: bool) -> void:
	"""Released inside a tunnel. From a move (or with no POI) it comes up at the far mouth and idles
	there; from a work order it keeps its slot and carries on to the POI, as on the surface, and
	works the bout in hand."""
	if was_move or poi < 0:
		release_slot()
		_idle_on_surface = true
		_leave_below()
		return
	_bouts_left = mini(_bouts_left, 1)
	_trip_s = 0.0


func _leave_below() -> void:
	"""Underground under a new order or a release: holding at a node below (a carrier in a cellar), walk out to the
	nearest mouth; walking, finish the stretch to the mouth it comes up at (see `_finish_tunnel_then_stop`)."""
	if state == State.HOLD or state == State.FACE:
		_walk_out()
	else:
		_finish_tunnel_then_stop()


func _start_ordered_trip(goal_at: Vector2) -> void:
	"""Plan to `goal_at` and set off (turning first); an order never carries. Underground, it finishes
	the tunnel first and plans from the mouth it comes up at. A new order overrides an earlier
	release's idling on the surface (and a finished dig's taking its saved job up once clear of the hole). On the
	surface it sets off through the routing desk (see ROUTING)."""
	_idle_on_surface = false
	_resume_on_surface = false
	_forget_step_out()
	_leave_line()
	carrying = false
	_bouts_left = 0
	_goal = goal_at
	_goal_node = -1
	_replans = 0
	_start_trip_record()
	if underground or state == State.CROSS:
		_leave_below()
		return
	if in_water:
		_space.crossings.swim_ashore(self)
		return
	if position.distance_to(goal_at) <= ARRIVE_RADIUS_M:
		_arrive()
		return
	_set_off(true, false, _carry_order)


func _hold_here() -> void:
	"""Hold where it stands -- after turning to face _hold_face, when the order gave one. A digger that has stepped
	clear of the hole its finished piece left takes up its saved job now (RESUMING; at night it keeps it)."""
	if _faces_on_hold and _hold_face.distance_to(position) > 0.05:
		_enter_turn(yaw_of(_hold_face - position), CLIP_WALK)
		state = State.FACE
	else:
		_enter_hold()
	if _resume_after_dig:
		_resume_after_dig = false
		take_up_unfinished()


func _enter_hold() -> void:
	"""Stand still, idling, facing the way it came; only an order or release moves it on."""
	state = State.HOLD
	carrying = false
	_set_clip(CLIP_IDLE, 1.0)


# --- farm tasks (demo/farm/) ------------------------------------------------------------------

func order_carry(goal_at: Vector2, face_toward: Vector2 = Vector2.INF) -> void:
	"""order_move(), walking with the carry clip when this resident has one -- the farm's harvest to
	the store, and water or spoil to a bed. A route through a tunnel is planned again LOADED (HAULING:
	the routine's own rule, `_plan_loaded`), so the load goes below only through a bore it fits, and
	on the surface otherwise. Arriving drops the load. It sets off carrying when its route is planned (see ROUTING)."""
	_carry_order = true
	order_move(goal_at, face_toward)
	_carry_order = false


func order_carry_below(node: int, face_toward: Vector2) -> void:
	"""order_carry() DOWN to `node` underground (a root cellar's middle: the carrier walks in, decision 0210): the trip
	is planned LOADED, so the load goes below only through bores it fits (HAULING); with no such way it walks down
	empty-handed. Arriving, it turns to `face_toward` and holds there, below, until released or ordered on (then it
	walks out). Not taken while the water's rescue holds it."""
	if water_hold:
		return
	release_slot()
	_leave_dig()
	_drop_task()
	order = ORDER_MOVE
	_faces_on_hold = true
	_hold_face = face_toward
	_carry_order = true
	_start_trip_below(node)
	_carry_order = false


func can_haul_below(node: int) -> bool:
	"""Whether this resident could carry a load down to `node` through bores the load fits (HAULING; a load that fits
	no bore reaches no mouth)."""
	var tunnels := _space.tunnels
	return can_carry() and tunnels.paths.nearest_mouth(tunnels, node, tunnels.walker_class(index, true)) >= 0


func play_in_place(name: StringName) -> bool:
	"""While holding, play clip `name` where it stands (the farm's work at a bed, well or heap) --
	task_play()'s clip rule. False, changing nothing, when it is not holding."""
	if state != State.HOLD:
		return false
	task_play(name)
	return true


func activity() -> int:
	"""ACTIVITY_*: digging, in a tunnel, holding, wandering on its own, walking under an order, or
	working under one."""
	if state == State.ROUTE:
		return ACTIVITY_ROUTING
	if order == ORDER_TASK:
		return ACTIVITY_TASK
	if state == State.QUEUE:
		return ACTIVITY_QUEUE
	if state == State.DIG or (state == State.TUNNEL and _travel_to_face):
		return ACTIVITY_DIGGING
	if state == State.TUNNEL:
		return ACTIVITY_TUNNEL
	if state == State.CROSS:
		return ACTIVITY_CROSSING
	if state == State.HOLD or (order == ORDER_MOVE and state == State.FACE):
		return ACTIVITY_HOLDING
	if order == ORDER_NONE:
		return ACTIVITY_WANDERING
	if state == State.WALK or state == State.TURN:
		return ACTIVITY_WALKING
	return ACTIVITY_WORKING


func goal() -> Vector2:
	"""Where the current trip is going (meaningful while walking or turning)."""
	return _goal


func surface_point() -> Vector2:
	"""Where this resident stands on the surface -- or, underground, the mouth it will come up at."""
	if state == State.CROSS:
		return path[path_index]
	if not underground:
		return position
	var exit := _stretch_end_node() if state == State.TUNNEL and not _travel_to_face and not _travel_for_task else -1
	if exit >= 0 and _space.tunnels.node_mouth[exit] >= 0:
		return _space.tunnels.node_m(exit)
	var start: int = _space.tunnels.node_a[_travel_slot]
	var m: int = _space.tunnels.paths.nearest_mouth(_space.tunnels, start, _fit_class())
	return _space.tunnels.mouth_at(m) if m >= 0 else position


func crosses_tunnel() -> bool:
	"""Whether the current route goes through a tunnel."""
	return path_tunnel.count(TunnelRouterScript.SURFACE_LEG) != path_tunnel.size()


# --- tunnels --------------------------------------------------------------------------------

func _leg(k: int) -> int:
	"""The leg code into waypoint `k`: SURFACE_LEG, a segment walked, or a crossing."""
	return path_tunnel[k] if k < path_tunnel.size() else TunnelRouterScript.SURFACE_LEG


func _is_bore_leg(k: int) -> bool:
	"""Whether waypoint `k` is reached by walking a segment of the network (not the surface, not the water)."""
	var code := _leg(k)
	return code != TunnelRouterScript.SURFACE_LEG and not TunnelRouterScript.is_crossing_code(code)


func _set_underground(below: bool) -> void:
	"""Go below the surface, or come back up onto it."""
	underground = below
	_space.set_underground(index, below)
	if not below:
		ground_y_m = 0.0
		pitch = 0.0


func _enter_tunnel_leg() -> void:
	"""At a mouth: go down and walk the segment the leg into path[path_index] names -- or, at a crossing's end,
	start across it (see THE WATER). A segment closed or cut since the plan sends it round by another way."""
	var code := path_tunnel[path_index]
	if TunnelRouterScript.is_crossing_code(code):
		_enter_crossing(code)
		return
	var tunnels := _space.tunnels
	if not tunnels.is_usable(TunnelRouterScript.leg_slot(code)) or tunnels.topology != _route_topology:
		_replan_or_abandon()
		return
	var mouth := tunnels.entry_mouth_of(code)
	if mouth >= 0:
		tunnels.queue.take(mouth, index)
		_holds_grant = true
	_start_leg(code)


func _start_leg(code: int) -> void:
	"""Walk one segment end to end, as leg `code` says (node A to B, or B to A)."""
	var slot_index := TunnelRouterScript.leg_slot(code)
	var length := _space.tunnels.length_m(slot_index)
	if TunnelRouterScript.leg_reversed(code):
		_start_travel(slot_index, length, 0.0)
	else:
		_start_travel(slot_index, 0.0, length)


func _start_travel(slot_index: int, from_m: float, to_m: float) -> void:
	"""Walk segment `slot_index` underground from `from_m` to `to_m` metres along it."""
	_travel_slot = slot_index
	_travel_m = from_m
	_travel_start_m = from_m
	_travel_end_m = to_m
	_travel_forward = to_m >= from_m
	_side_m = 0.0
	_emerge_waited = 0.0
	state = State.TUNNEL
	_set_underground(true)
	_set_clip(CLIP_CARRY if carrying else CLIP_WALK, _bore_clip_speed())
	_place_in_tunnel()


func _step_tunnel(delta: float) -> void:
	"""Walk on along the segment at walk speed, keeping its distance from anyone ahead and stepping aside for
	anyone coming (see SHARING A BORE); at its end, go on into the next segment, come up once the hole is
	clear, or reach the dig face. Stranded (no way out), wait and look again."""
	if _stranded_s >= 0.0:
		_wait_stranded(delta)
		return
	var wanted := _bore_speed() * delta * slope_share()
	var step_m := minf(wanted, _space.room_ahead(index, BORE_GAP_M))
	clip_speed = _bore_clip_speed() * (step_m / wanted if wanted > 0.0 else 0.0)
	_travel_m = move_toward(_travel_m, _travel_end_m, step_m)
	var side_target := PASS_OFFSET_M if _space.oncoming(index, PASS_WINDOW_M) else 0.0
	_side_m = move_toward(_side_m, side_target, SIDE_STEP_M_S * delta)
	_place_in_tunnel()
	if _holds_grant and absf(_travel_m - _travel_start_m) > TunnelQueueScript.HOLD_M:
		_space.tunnels.queue.release_grant(index)
		_holds_grant = false
	if _travel_m != _travel_end_m:
		return
	if _surfaces_here() and not _travel_to_face and not _travel_for_task and _emerge_blocked():
		_emerge_waited += delta
		return
	_end_travel()


func _wait_stranded(delta: float) -> void:
	"""Stranded underground, every way out closed: stand, and look for a way out every RETRY_S."""
	_stranded_s += delta
	_set_clip(CLIP_IDLE, 1.0)
	if _stranded_s >= RETRY_S:
		_stranded_s = -1.0
		_walk_out()


func slope_share() -> float:
	"""How much of a step along the floor here is flat route distance: the cosine of its slope (see RAMPS; 1
	on the level)."""
	var grade := _space.tunnels.floor_grade_at(_travel_slot, _travel_m)
	return 1.0 / sqrt(1.0 + grade * grade)


## A resident on a link between the levels, out of both levels' sight (demo_layers.gd's, the one value).
const BETWEEN_LEVELS: int = LayersScript.BETWEEN_LEVELS


func view_level() -> int:
	"""The level this resident is drawn on (decision 0212): 0 on the surface, else its segment's level -- on a link,
	its head's while its floor is within a bore's crown of the head's floor (seen through level 1's section there),
	its foot's once its floor lies under the foot's section (seen from level 2), and BETWEEN_LEVELS on the hidden
	middle, where each level's section is solid earth over it (demo_layers.gd `body_mask`, `marker_mask`)."""
	var at := _space.resident_tunnel[index] if underground else -1
	if at < 0:
		return TunnelRules.LEVEL_SURFACE
	var tunnels := _space.tunnels
	var level: int = tunnels.seg_level[at]
	if tunnels.seg_kind[at] != CastSpaceScript.GraphScript.SEG_LINK:
		return level
	var floor_y: float = tunnels.floor_y_at(at, _space.resident_along[index])
	if floor_y >= TunnelRules.level_floor_m(level) - TunnelRules.crown_m(TunnelRules.BORE_STANDARD):
		return level
	var foot_cut := TunnelRules.level_floor_m(level + 1) + TunnelRules.crown_m(TunnelRules.BORE_WIDE)
	return level + 1 if floor_y <= foot_cut else BETWEEN_LEVELS


func bore_class() -> int:
	"""The bore class of the segment it is in (TunnelRules.BORE_*), or -1 on the surface."""
	var at := _space.resident_tunnel[index] if underground else -1
	return int(_space.tunnels.bore[at]) if at >= 0 else -1


func _bore_speed() -> float:
	"""Walking speed in the bore being walked: the carry's own pace with a load, else walk speed, times the
	bore's speed (faster when lit; see WEATHER AND LANTERNS)."""
	var base := _carry_speed if carrying and _carry_speed > 0.0 else walk_speed
	return base * float(_space.tunnels.speed_permille(_travel_slot)) / float(TunnelRules.PERMILLE)


func _travel_node() -> int:
	"""The node the current segment walk ends at (-1: it ends partway along, a task's place)."""
	var tunnels := _space.tunnels
	if _travel_end_m >= tunnels.length_m(_travel_slot) - 1e-4:
		return tunnels.node_b[_travel_slot]
	return tunnels.node_a[_travel_slot] if _travel_end_m <= 1e-4 else -1


func _surfaces_here() -> bool:
	"""Whether this walk comes up where it ends: at a mouth, with no segment of the route after it."""
	var node := _travel_node()
	return node >= 0 and _space.tunnels.node_mouth[node] >= 0 and not _is_bore_leg(path_index + 1)


func _emerge_blocked() -> bool:
	"""Whether someone on the surface stands on the mouth this walk comes up at, and the wait for them
	(EMERGE_WAIT_S) is not yet over."""
	return _emerge_waited < EMERGE_WAIT_S \
			and _space.surface_occupied(index, _space.tunnels.point_at(_travel_slot, _travel_end_m), EMERGE_CLEAR_M)


func _place_in_tunnel() -> void:
	"""Stand on the bore floor at the current distance along the segment, facing the way it walks, stepped
	`_side_m` to its right; and record its place in the bore."""
	stand_in_bore(_travel_slot, _travel_m, _travel_forward)
	var facing := forward()
	position += Vector2(-facing.y, facing.x) * _side_m
	_space.move_resident(index, position)
	_space.set_in_bore(index, _travel_slot, _travel_m, 1 if _travel_forward else -1)


func stand_in_bore(slot_index: int, along_m: float, facing_forward: bool) -> void:
	"""Stand on segment `slot_index`'s floor `along_m` in, on its drawn centreline (bore_curve.gd, the one the
	bore is swept along), facing along it (or back), tilted with its ramp (see RAMPS)."""
	var tunnels := _space.tunnels
	BoreCurveScript.of(tunnels, slot_index).sample(along_m, _curve_sample)
	var facing: Vector2 = _curve_sample[1] if facing_forward else -_curve_sample[1]
	position = _curve_sample[0]
	yaw = yaw_of(facing)
	ground_y_m = tunnels.floor_y_at(slot_index, along_m)
	var grade := tunnels.floor_grade_at(slot_index, along_m)
	pitch = atan(-grade if facing_forward else grade)


func _end_travel() -> void:
	"""At the end of a segment walk: start digging at the face, hand back to a task, walk on into the next
	segment of the route, arrive at a goal underground -- or come up and go on."""
	if _holds_grant:
		_space.tunnels.queue.release_grant(index)
		_holds_grant = false
	if _travel_to_face:
		_travel_to_face = false
		_enter_dig_state()
		return
	if _travel_for_task:
		_travel_for_task = false
		state = State.TASK
		return
	if _is_bore_leg(path_index + 1):
		_next_segment()
		return
	var node := _travel_node()
	if node >= 0 and _space.tunnels.node_mouth[node] < 0:
		_arrive_below(node)
		return
	_set_underground(false)
	_go_on_from_mouth()


func _next_segment() -> void:
	"""On at a node into the route's next segment -- or, when it was closed, the network changed since the
	plan, or this walk ended elsewhere (a split), by the way that is best now to where this stretch of the
	route was going (MOVE-REQ-006: the route is checked again before entry)."""
	var here := _travel_node()
	var target := _stretch_end_node()
	path_index += 1
	var tunnels := _space.tunnels
	var code := path_tunnel[path_index]
	if tunnels.is_usable(TunnelRouterScript.leg_slot(code)) and tunnels.topology == _route_topology \
			and tunnels.leg_start_node(code) == here:
		_start_leg(code)
		return
	_reroute_below(here, target)


func _stretch_end_node() -> int:
	"""Where the segments of the route from here on end: its exit mouth, or its goal underground."""
	var last := path_index
	while _is_bore_leg(last + 1):
		last += 1
	return _space.tunnels.leg_end_node(path_tunnel[last]) if _is_bore_leg(last) else -1


func _reroute_below(node: int, target: int) -> void:
	"""At `node` underground with the rest of the route gone stale: on to `target` (the exit mouth or the goal
	below) by the way best now, else out at the nearest mouth to plan again on the surface."""
	if target >= 0 and target != node and _route_between(node, target):
		_start_leg(path_tunnel[0])
		return
	_walk_out_from(node)


func _arrive_below(node: int) -> void:
	"""The route ended at a node underground: the goal of a dig or a task, else (cut short) out to the nearest
	mouth."""
	if node == _goal_node and (order == ORDER_DIG or order == ORDER_TASK or order == ORDER_MOVE):
		_goal_node = -1
		_arrive()
		return
	_walk_out_from(node)


func _go_on_from_mouth() -> void:
	"""Up at a mouth, or off a crossing: step out of the hole (a digger done), idle (released on the way), go
	on along the route, arrive, or plan again when the route ended here short of the goal."""
	if _step_out_on_surface:
		_step_out_on_surface = false
		_step_clear(forward())
		return
	if _idle_on_surface:
		_idle_on_surface = false
		if _take_up_on_surface():
			return
		_enter_idle(rng.randf_range(IDLE_MIN_S * 0.5, IDLE_MIN_S))
		return
	if path_index < path.size() - 1:
		path_index += 1
		_flips = 0
		_reset_progress()
		_enter_turn(yaw_of(path[path_index] - position), _locomotion_clip())
	elif position.distance_to(_goal) <= ARRIVE_RADIUS_M and _goal_node < 0:
		_arrive()
	else:
		_set_off(true, carrying, false)


func turn_back(slot_index: int, to_m: float) -> void:
	"""The segment this resident is walking has closed ahead (tunnel_hazards.gd): walk to `to_m` along it
	instead -- an end on its side -- and from there out by another way, or up and round (the route is cut at
	this leg). Anyone not walking that segment is left alone."""
	if state != State.TUNNEL or _travel_slot != slot_index or _travel_for_task or _travel_to_face:
		return
	_travel_end_m = to_m
	_travel_forward = to_m >= _travel_m
	path.resize(path_index + 1)
	path_tunnel.resize(path_index + 1)
	_goal_node = -1


func is_in_bore(slot_index: int) -> bool:
	"""Whether this resident is walking or standing in segment `slot_index`'s bore."""
	return underground and _space.resident_tunnel[index] == slot_index


func bore_along_m() -> float:
	"""How far along the bore it is in (meaningful underground)."""
	return _travel_m


func _finish_tunnel_then_stop() -> void:
	"""Underground under a new order: keep walking to the mouth this stretch of the route comes up at (the
	route ends there), then plan the order from it. Committed progress is never undone mid-tunnel
	(MOVE-REQ-007)."""
	var last := path_index
	while _is_bore_leg(last + 1):
		last += 1
	path.resize(last + 1)
	path_tunnel.resize(last + 1)
	_goal_node = -1


func repoint_split(old_slot: int, new_slot: int, split_m: float) -> void:
	"""Segment `old_slot` was split at `split_m` (underground_graph.gd PIECES): a walker in it past the split
	is in `new_slot` now, as far past the split; its route is checked again at its next node."""
	if not underground or state != State.TUNNEL or _travel_slot != old_slot:
		return
	if _travel_m <= split_m:
		_travel_end_m = minf(_travel_end_m, split_m)
		return
	_travel_slot = new_slot
	_travel_m -= split_m
	_travel_start_m = maxf(_travel_start_m - split_m, 0.0)
	_travel_end_m = maxf(_travel_end_m - split_m, 0.0)
	_place_in_tunnel()


# --- ways out, and ways to a node underground ----------------------------------------------

func _fit_class() -> int:
	"""The segments this resident may walk now (graph_paths.gd CLASS_*), carrying or not; one that fits no
	bore but is below anyway (a digger's crew never is) may use any."""
	var fit_class: int = _space.tunnels.walker_class(index, carrying)
	return fit_class if fit_class != GraphPathsScript.CLASS_NONE else GraphPathsScript.CLASS_ANY


func _walk_out() -> void:
	"""Walk from where it stands in its bore to the nearest mouth it can reach through usable segments, the way
	cheapest now: a route whose first leg is the rest of this segment to the better end."""
	var slot_index := _space.resident_tunnel[index]
	if slot_index < 0:
		slot_index = _travel_slot
	var tunnels := _space.tunnels
	var best_end := -1
	var best_cost := GraphPathsScript.UNREACHED
	for end in _ends_open(slot_index):
		var node: int = tunnels.end_node(slot_index, end == 1)
		var run := TunnelRules.to_u(absf((tunnels.length_m(slot_index) if end == 1 else 0.0) - _travel_m))
		var cost := run + _cost_out(node)
		if cost < best_cost:
			best_cost = cost
			best_end = end
	_leave_by(slot_index, best_end)


func _cost_out(node: int) -> int:
	"""What the cheapest walk from `node` up to a mouth costs (u; UNREACHED: none)."""
	var tunnels := _space.tunnels
	if tunnels.node_mouth[node] >= 0:
		return 0
	var m: int = tunnels.paths.nearest_mouth(tunnels, node, _fit_class())
	return tunnels.paths.dist_u(tunnels, _fit_class(), m, node) if m >= 0 else GraphPathsScript.UNREACHED


func _leave_by(slot_index: int, end: int) -> void:
	"""Walk the rest of segment `slot_index` to its node A (end 0) or B (end 1), then out to the nearest mouth;
	with no way out from either end (end -1), stand stranded and look again later."""
	_travel_to_face = false
	_travel_for_task = false
	_goal_node = -1
	if end < 0:
		_stranded_s = 0.0
		state = State.TUNNEL
		return
	var tunnels := _space.tunnels
	var node: int = tunnels.end_node(slot_index, end == 1)
	path.clear()
	path_tunnel.clear()
	path.append(tunnels.node_m(node))
	path_tunnel.append(TunnelRouterScript.leg_code(slot_index, end == 0))
	_append_way_out(node)
	path_index = 0
	_route_topology = tunnels.topology
	_start_travel(slot_index, _travel_m, tunnels.length_m(slot_index) if end == 1 else 0.0)


func _walk_out_from(node: int) -> void:
	"""Standing at `node` underground: out to the nearest mouth, the way cheapest now (stranded when there is
	none)."""
	var tunnels := _space.tunnels
	var m: int = tunnels.paths.nearest_mouth(tunnels, node, _fit_class())
	if m < 0:
		_goal_node = -1
		_stranded_s = 0.0
		state = State.TUNNEL
		return
	path.clear()
	path_tunnel.clear()
	_append_way_out(node)
	path_index = 0
	_route_topology = tunnels.topology
	_goal_node = -1
	_start_leg(path_tunnel[0])


func _append_way_out(node: int) -> void:
	"""Append to the route the segments of the cheapest walk from `node` up to the nearest mouth."""
	var tunnels := _space.tunnels
	if tunnels.node_mouth[node] >= 0:
		return
	var m: int = tunnels.paths.nearest_mouth(tunnels, node, _fit_class())
	if m >= 0:
		_append_walk(m, node, true)


func _append_walk(m: int, node: int, outward: bool) -> void:
	"""Append the segments of the cheapest walk between mouth `m` and `node`: from the mouth in, or (outward)
	from the node out to the mouth."""
	var tunnels := _space.tunnels
	tunnels.paths.path_into(tunnels, _fit_class(), m, node, _segments)
	if outward:
		_segments.reverse()
	var at: int = node if outward else tunnels.mouth_node[m]
	for slot_index in _segments:
		var reverse: bool = tunnels.node_a[slot_index] != at
		at = tunnels.other_end(slot_index, at)
		path.append(tunnels.node_m(at))
		path_tunnel.append(TunnelRouterScript.leg_code(slot_index, reverse))


func _route_between(from_node: int, to_node: int) -> bool:
	"""Replace the route with the cheapest walk from `from_node` to `to_node` through usable segments
	(graph_paths.gd `path_between`). False (the route left as it was) when there is none."""
	var tunnels := _space.tunnels
	if not tunnels.paths.path_between(tunnels, _fit_class(), from_node, to_node, _segments):
		return false
	path.clear()
	path_tunnel.clear()
	var at := from_node
	for slot_index in _segments:
		var reverse: bool = tunnels.node_a[slot_index] != at
		at = tunnels.other_end(slot_index, at)
		path.append(tunnels.node_m(at))
		path_tunnel.append(TunnelRouterScript.leg_code(slot_index, reverse))
	path_index = 0
	_route_topology = tunnels.topology
	return true


func _plan_trip(allow_tunnels: bool, loaded: bool) -> void:
	"""Plan the trip from here to its goal -- on the surface, or to its node underground -- into the route; its time
	is charged to this frame's routing budget (see ROUTING)."""
	var began := Time.get_ticks_usec()
	_space.plan_path(index, position, _goal, radius, path, path_tunnel, allow_tunnels or _goal_node >= 0, loaded, _goal_node)
	_route_topology = _space.tunnels.topology
	_space.routes.charge(index, Time.get_ticks_usec() - began)


# --- digging --------------------------------------------------------------------------------

func order_dig(tunnel_slot: int, tunnel_generation: int) -> void:
	"""Walk to segment (slot, generation)'s start and dig it until it opens, then the rest of its piece; then
	take up the next piece this resident digs, or come up and hold. The caller has started (or resumed) the
	segment with this resident as its digger. Not taken while the water's rescue holds it."""
	if water_hold:
		return
	release_slot()
	_leave_dig()
	_drop_task()
	dig_tunnel = tunnel_slot
	dig_generation = tunnel_generation
	order = ORDER_DIG
	_faces_on_hold = false
	var start: int = _space.tunnels.node_a[tunnel_slot]
	if _space.tunnels.node_mouth[start] >= 0:
		_start_ordered_trip(_space.tunnels.node_m(start))
	else:
		_start_trip_below(start)


func _start_trip_below(node: int) -> void:
	"""Walk to `node` underground: through the network from the surface, or on through it from below."""
	_idle_on_surface = false
	_resume_on_surface = false
	_forget_step_out()
	_leave_line()
	carrying = false
	_bouts_left = 0
	_goal = _space.tunnels.node_m(node)
	_goal_node = node
	_replans = 0
	_start_trip_record()
	if underground and _is_at_node(node):
		_goal_node = -1
		_arrive()
		return
	if underground:
		_reroute_below_from_here(node)
		return
	_set_off(true, false, _carry_order)


func _is_at_node(node: int) -> bool:
	"""Whether this resident stands at `node` underground."""
	var tunnels := _space.tunnels
	return tunnels.node_m(node).distance_to(position) < ARRIVE_RADIUS_M * 2.0


func _reroute_below_from_here(node: int) -> void:
	"""Underground, bound for `node`: finish this segment to whichever end it may walk to (only its node A,
	back through what is dug, while the segment is not open) that makes the cheaper way on, then on to the
	node. With no way on below from either end, out at the nearest mouth, still bound for the node: up there
	the trip is planned again, in at whichever mouth leads to it (`_go_on_from_mouth`)."""
	var tunnels := _space.tunnels
	var slot_index := _travel_slot
	var end := _end_toward(slot_index, node)
	if end < 0:
		_walk_out()
		_goal_node = node
		return
	var from: int = tunnels.end_node(slot_index, end == 1)
	if from != node:
		_route_between(from, node)
	else:
		path.clear()
		path_tunnel.clear()
	path.insert(0, tunnels.node_m(from))
	path_tunnel.insert(0, TunnelRouterScript.leg_code(slot_index, end == 0))
	path_index = 0
	_start_travel(slot_index, _travel_m, tunnels.length_m(slot_index) if end == 1 else 0.0)


func _end_toward(slot_index: int, node: int) -> int:
	"""Which end of segment `slot_index` to walk to from where this resident stands, bound for `node`: the one
	whose walk along the segment plus the cheapest way on to `node` costs least, of the ends it may reach
	(`_ends_open`). -1 when neither leads there."""
	var tunnels := _space.tunnels
	var best_end := -1
	var best_cost := GraphPathsScript.UNREACHED
	for end in _ends_open(slot_index):
		var run := TunnelRules.to_u(absf((tunnels.length_m(slot_index) if end == 1 else 0.0) - _travel_m))
		var cost := run + _cost_between(tunnels.end_node(slot_index, end == 1), node)
		if cost < best_cost:
			best_cost = cost
			best_end = end
	return best_end


func _ends_open(slot_index: int) -> PackedInt32Array:
	"""The ends of segment `slot_index` a resident in it may walk to: both of an open segment; of one still
	being dug, only node A, back through what is dug (MOVE-REQ-002: never through undug ground)."""
	return PackedInt32Array([0, 1]) if _space.tunnels.is_open(slot_index) else PackedInt32Array([0])


func _cost_between(from_node: int, to_node: int) -> int:
	"""The cheapest walk (u at walk speed) from one node to another through usable segments (UNREACHED: none)."""
	if from_node == to_node:
		return 0
	var tunnels := _space.tunnels
	if not tunnels.paths.path_between(tunnels, _fit_class(), from_node, to_node, _segments):
		return GraphPathsScript.UNREACHED
	var total := 0
	for slot_index in _segments:
		total += GraphPathsScript.edge_cost_u(tunnels, slot_index)
	return total


func dig_clip() -> StringName:
	"""The clip digging plays: the first of DIG_CLIPS this creature has, else idle."""
	for name in DIG_CLIPS:
		if has_clip(name):
			return name
	return CLIP_IDLE


func _begin_dig() -> void:
	"""At the segment's start: dig an entry shaft here on the surface, or walk to the face -- down from a mouth,
	or on from a node below. A segment that no longer exists leaves the digger holding."""
	var tunnels := _space.tunnels
	if not tunnels.is_ref(dig_tunnel, dig_generation):
		_forget_dig()
		order = ORDER_MOVE
		_enter_hold()
		return
	yaw = yaw_of(tunnels.direction_at(dig_tunnel, 0.0))
	if tunnels.stage(dig_tunnel) == TunnelRules.STAGE_ENTRANCE:
		_enter_dig_state()
		return
	_travel_to_face = true
	_start_travel(dig_tunnel, 0.0, tunnels.face_m(dig_tunnel))


func _enter_dig_state() -> void:
	"""Dig, playing the dig clip."""
	state = State.DIG
	_set_clip(dig_clip(), 1.0)


func _step_dig(delta: float) -> void:
	"""Work the segment's clock; follow its face underground once any entry shaft is through; when it opens,
	go on to the rest of the piece."""
	var tunnels := _space.tunnels
	tunnels.advance(dig_tunnel, dig_generation, roundi(delta * float(TunnelRules.USEC_PER_SECOND)))
	if tunnels.is_open(dig_tunnel):
		_finish_dig()
		return
	if tunnels.stage(dig_tunnel) == TunnelRules.STAGE_ENTRANCE:
		return
	if not underground:
		_set_underground(true)
	_travel_slot = dig_tunnel
	_travel_m = tunnels.face_m(dig_tunnel)
	stand_in_bore(dig_tunnel, _travel_m, true)
	_space.move_resident(index, position)
	_space.set_in_bore(index, dig_tunnel, _travel_m, 0)


func _finish_dig() -> void:
	"""The segment is open: dig on into the next of its piece where it starts here; with the piece done, take
	up the next piece this resident digs, else come up (at the mouth it broke out at, stepping clear of the
	hole) or walk out, and hold."""
	var tunnels := _space.tunnels
	var done_slot := dig_tunnel
	var next: int = tunnels.next_in_piece(done_slot)
	if next >= 0 and tunnels.start_dig(next, tunnels.generation[next], index):
		dig_tunnel = next
		dig_generation = tunnels.generation[next]
		_begin_dig()
		return
	_forget_dig()
	var queued: int = tunnels.next_dig_for(index)
	if queued >= 0 and tunnels.start_dig(queued, tunnels.generation[queued], index):
		order_dig(queued, tunnels.generation[queued])
		return
	_leave_finished(done_slot)


func _leave_finished(done_slot: int) -> void:
	"""A piece dug through: up at the mouth it broke out at, stepping clear of the hole; or, ended underground,
	out by the nearest mouth, stepping clear there."""
	var tunnels := _space.tunnels
	order = ORDER_MOVE
	_faces_on_hold = false
	if tunnels.node_mouth[tunnels.node_b[done_slot]] < 0:
		_travel_slot = done_slot
		_travel_m = tunnels.length_m(done_slot)
		_step_out_on_surface = true
		_walk_out()
		return
	var outward := tunnels.direction_at(done_slot, tunnels.length_m(done_slot))
	position = tunnels.end_at(done_slot, true)
	yaw = yaw_of(outward)
	_set_underground(false)
	_space.move_resident(index, position)
	_step_clear(outward)


func _forget_step_out() -> void:
	"""A new order or a release: no stepping clear of a finished hole once up, nor taking the saved job up after it -- the
	player's word wins (RESUMING)."""
	_step_out_on_surface = false
	_resume_after_dig = false


func _step_clear(outward: Vector2) -> void:
	"""Up out of a hole facing `outward`: step clear of it -- the first of STEP_OUT_TURNS that is clear -- and
	hold there; hold where it stands when none is."""
	order = ORDER_MOVE
	for turn in STEP_OUT_TURNS:
		var clear := position + outward.rotated(turn) * STEP_OUT_M
		if step_out_ok(clear):
			order_move(clear)
			_resume_after_dig = true
			return
	_faces_on_hold = false
	_resume_after_dig = true
	_hold_here()


func step_out_ok(at: Vector2) -> bool:
	"""Whether a digger up out of a hole may step to `at`: inside the village by its radius, clear of every
	obstacle by STEP_OUT_CLEAR_M, off every mouth's hole and nobody standing there."""
	if not _space.bounds.grow(-radius).has_point(at):
		return false
	if _space.obstacle_clearance(at) < radius + STEP_OUT_CLEAR_M:
		return false
	if _space.on_mouth(at, radius):
		return false
	return not _space.surface_occupied(index, at, STEP_OUT_CLEAR_M)


func _forget_dig() -> void:
	"""Hold no dig reference: the null EntityRef (-1, 0)."""
	dig_tunnel = -1
	dig_generation = 0


func _leave_dig(unreached: bool = false) -> void:
	"""Stop digging, if it was: the segment is paused with its progress (or its piece dropped, if nothing of it
	was dug) -- or, `unreached`, kept paused as it stands. Underground, the digger backs out through what it
	dug and on out of the network."""
	if dig_tunnel < 0:
		return
	var slot_index := dig_tunnel
	if unreached:
		_space.tunnels.hold_unreached(slot_index, dig_generation)
	else:
		_space.tunnels.stop_digging(slot_index, dig_generation)
		_remember_dig(slot_index, dig_generation)
	_forget_dig()
	if state == State.DIG and underground:
		_back_out(slot_index, _space.tunnels.face_m(slot_index))
	elif state == State.TUNNEL and _travel_to_face:
		_back_out(slot_index, _travel_m)


func _take_up_on_surface() -> bool:
	"""Up from a task that ended underground: take up the latest unfinished job, if one waits."""
	var wanted: bool = _resume_on_surface
	_resume_on_surface = false
	return wanted and order == ORDER_NONE and not water_hold and not in_water and take_up_unfinished()


func _remember_dig(slot_index: int, generation: int) -> void:
	"""A dig left paused with its progress (not dropped: something was dug) is an unfinished job. It is held
	by a DigBack, never by a Callable on this brain: the brain holds its jobs, so a job holding the brain
	would be a reference cycle that is never freed."""
	if _space.tunnels.is_ref(slot_index, generation):
		remember_unfinished(UnfinishedScript.new(DigBack.new(slot_index, generation).take_back,
			"Dig tunnel %d" % (slot_index + 1)))


func resume_dig(slot_index: int, generation: int) -> bool:
	"""Dig segment (slot, generation) again, if it is still paused waiting for a digger."""
	if not _space.tunnels.resume(slot_index, generation, index):
		return false
	order_dig(slot_index, generation)
	return true


## A paused dig to come back to (see _remember_dig).
class DigBack extends RefCounted:
	var slot_index: int = -1
	var generation: int = 0

	func _init(p_slot: int, p_generation: int) -> void:
		"""Segment (slot, generation)."""
		slot_index = p_slot
		generation = p_generation

	func take_back(brain: RefCounted) -> bool:
		"""Send `brain` back to dig it."""
		return bool(brain.call(&"resume_dig", slot_index, generation))


func remember_unfinished(job: UnfinishedScript) -> void:
	"""Keep an unfinished job to come back to (see RESUMING), taken next: the latest RESUME_MAX are kept, and one kept
	again (the same words: the same job) moves to the latest place rather than twice. A player's queued entries are
	kept apart (see THE ORDER LIST)."""
	if job == null:
		return
	_forget_label(job.label())
	_unfinished.append(job)
	while _returns() > RESUME_MAX:
		_unfinished.remove_at(_oldest_return())
	queue_revision += 1


func append_queued(job: UnfinishedScript) -> bool:
	"""THE ORDER LIST: the player's queued order, taken after everything already on the list. False -- nothing kept --
	when it holds QUEUE_MAX queued orders already or that very entry (the same words) is on it."""
	if job == null or not can_queue():
		return false
	for kept: UnfinishedScript in _unfinished:
		if kept.label() == job.label():
			return false
	job.queued = true
	_unfinished.insert(0, job)
	queue_revision += 1
	return true


func can_queue() -> bool:
	"""Whether its order list has room for another queued order (QUEUE_MAX)."""
	return _unfinished.size() - _returns() < QUEUE_MAX


func forget_task(task_source: int, task_key: int) -> bool:
	"""It has that work board task now -- taken up from its list, claimed, reassigned: every entry naming it goes, so a
	stale one is never taken up later (see THE ORDER LIST). Whether one went."""
	var gone: bool = false
	for k: int in range(_unfinished.size() - 1, -1, -1):
		if _unfinished[k].names_task(task_source, task_key):
			_unfinished.remove_at(k)
			gone = true
	if gone:
		queue_revision += 1
	return gone


func _forget_label(words: String) -> void:
	"""Drop every entry with these words (the same job kept again)."""
	for k: int in range(_unfinished.size() - 1, -1, -1):
		if _unfinished[k].label() == words:
			_unfinished.remove_at(k)


func _returns() -> int:
	"""How many entries were kept from interruptions (not queued by the player)."""
	var n: int = 0
	for kept: UnfinishedScript in _unfinished:
		n += 0 if kept.queued else 1
	return n


func _oldest_return() -> int:
	"""The list index of the oldest entry kept from an interruption (called only while there is one)."""
	for k: int in _unfinished.size():
		if not _unfinished[k].queued:
			return k
	return 0


func queue_size() -> int:
	"""How many entries its order list holds (see THE ORDER LIST)."""
	return _unfinished.size()


func queue_entry(k: int) -> UnfinishedScript:
	"""Entry `k` of its order list in take order (0: taken next); null out of range."""
	if k < 0 or k >= _unfinished.size():
		return null
	return _unfinished[_unfinished.size() - 1 - k]


func remove_queued(k: int) -> bool:
	"""The player removes entry `k` (take order) from its order list. False out of range."""
	if k < 0 or k >= _unfinished.size():
		return false
	_unfinished.remove_at(_unfinished.size() - 1 - k)
	queue_revision += 1
	return true


func move_queued(k: int, by: int) -> bool:
	"""The player moves entry `k` (take order) `by` places later (negative: sooner). False when it cannot move."""
	var to: int = k + by
	if k < 0 or k >= _unfinished.size() or to < 0 or to >= _unfinished.size() or by == 0:
		return false
	var job: UnfinishedScript = _unfinished[_unfinished.size() - 1 - k]
	_unfinished.remove_at(_unfinished.size() - 1 - k)
	_unfinished.insert(_unfinished.size() - to, job)
	queue_revision += 1
	return true


func promises(task_source: int, task_key: int) -> bool:
	"""Whether its order list means to take up that work board task (see THE ORDER LIST)."""
	for kept: UnfinishedScript in _unfinished:
		if kept.names_task(task_source, task_key):
			return true
	return false


func take_up_unfinished() -> bool:
	"""Take up the latest unfinished job that still waits for this resident, dropping stale ones on the way.
	True when one was taken up. Not at night (`resting`): the jobs stay kept for the morning, and the night routine
	sends it to bed (decision 0210)."""
	if resting:
		return false
	while not _unfinished.is_empty():
		var job: UnfinishedScript = _unfinished.pop_back()
		queue_revision += 1
		if job.resume(self):
			forget_task(job.source, job.key)
			return true
	return false


func unfinished_labels() -> PackedStringArray:
	"""The unfinished jobs it will come back to, latest first, in words (for the panel)."""
	var words := PackedStringArray()
	for k: int in range(_unfinished.size() - 1, -1, -1):
		words.append(_unfinished[k].label())
	return words


func _back_out(slot_index: int, from_m: float) -> void:
	"""Walk back from `from_m` along segment `slot_index` to its start (node A: the only way out of a bore
	being dug), then out of the network by the nearest mouth."""
	_travel_m = from_m
	_leave_by(slot_index, 0)


# --- tasks ----------------------------------------------------------------------------------

func order_task(new_task: TaskScript) -> void:
	"""Hand this resident to `new_task` (see TASKS): give up any slot, dig, line or earlier task, walk to the
	task's site and let it drive from there. Not taken while the water's rescue holds it."""
	if water_hold:
		return
	release_slot()
	_leave_dig()
	_drop_task()
	task = new_task
	order = ORDER_TASK
	_faces_on_hold = false
	var below: int = new_task.site_node(self)
	if below >= 0:
		_start_trip_below(below)
	else:
		_start_ordered_trip(new_task.site(self))


func task_label() -> String:
	"""What the task driving this resident is doing, in words ("" with none)."""
	return task.label() if task != null else ""


func _step_task(delta: float) -> void:
	"""Let the task drive; when it is done, go back to the routine."""
	if task == null or not task.step(self, delta):
		_finish_task()


func _finish_task() -> void:
	"""The task is over: back to the latest unfinished job (see RESUMING), else to wandering. Ended underground,
	it walks out to the nearest mouth first and takes the job up there (a job is never started from inside a
	bore)."""
	var done_task := task
	task = null
	order = ORDER_NONE
	if done_task != null:
		done_task.finish(self)
	if underground:
		_idle_on_surface = true
		_resume_on_surface = true
		_walk_out()
		return
	if not water_hold and not in_water and take_up_unfinished():
		return
	_enter_idle(rng.randf_range(IDLE_MIN_S * 0.5, IDLE_MIN_S))


func _drop_task() -> void:
	"""Another order or a release takes this resident from its task: the task is told, the job is kept to come
	back to when it can be (see RESUMING), and one standing in a bore walks out to the nearest mouth first."""
	if task == null:
		return
	var dropped := task
	task = null
	_travel_for_task = false
	dropped.cancel(self)
	remember_unfinished(dropped.unfinished())
	if underground:
		_walk_out()


func task_walk_to(point: Vector2) -> void:
	"""For a task: walk (on the surface, through tunnels if quicker) to `point`; the task's arrived() is called
	there."""
	_goal = point
	_goal_node = -1
	_replans = 0
	_start_trip_record()
	if position.distance_to(point) <= ARRIVE_RADIUS_M:
		_arrive()
		return
	_set_off(true, false, false)


func task_carry_to(point: Vector2) -> void:
	"""For a task: `task_walk_to` with a load -- the carry clip when this creature has one, and a route through a tunnel
	planned again LOADED, as `order_carry`'s is (HAULING): the kitchen's cook with the food or the pot, a drawer with
	water (decision 0381)."""
	carrying = can_carry() and not underground
	task_walk_to(point)
	if state != State.TURN and state != State.WALK:
		carrying = false
	elif carrying and crosses_tunnel():
		_plan_loaded(INF)
		_begin_leg()


func task_walk_to_node(node: int) -> void:
	"""For a task: walk to network node `node` -- a mouth on the surface, or a node underground reached
	through the network; the task's arrived() is called there."""
	if _space.tunnels.node_mouth[node] >= 0:
		task_walk_to(_space.tunnels.node_m(node))
		return
	_start_trip_below(node)


func task_enter_bore(slot_index: int, from_m: float, to_m: float) -> void:
	"""For a task: go down segment `slot_index` at `from_m` (a mouth it stands at, or a node below) and walk
	to `to_m` in it, where the task takes over again (TASK), still underground."""
	_travel_for_task = true
	_start_travel(slot_index, from_m, to_m)


func task_stand_in_bore(slot_index: int, along_m: float, facing_forward: bool) -> void:
	"""For a task: stand in segment `slot_index`'s bore `along_m` from its node A, facing its node B (or A).
	Standing, it heads neither way in the bore (heading 0), so walkers never queue up behind it: they step
	aside and pass, as for someone coming the other way."""
	_travel_slot = slot_index
	_travel_m = along_m
	_travel_forward = facing_forward
	_side_m = 0.0
	if not underground:
		_set_underground(true)
	_place_in_tunnel()
	_space.set_in_bore(index, slot_index, along_m, 0)


func task_surface_at(node: int) -> void:
	"""For a task: come up out of the network at mouth node `node`."""
	position = _space.tunnels.node_m(node)
	_set_underground(false)
	_space.move_resident(index, position)


func task_tunnel_to(from_node: int, to_node: int) -> bool:
	"""For a task: from mouth node `from_node` (standing at it) walk the network to mouth node `to_node` the
	cheapest way, and come up there (TASK again, on the surface). False when there is no such way."""
	var tunnels := _space.tunnels
	var m: int = tunnels.node_mouth[from_node]
	if m < 0 or tunnels.paths.dist_u(tunnels, _fit_class(), m, to_node) >= GraphPathsScript.UNREACHED:
		return false
	path.clear()
	path_tunnel.clear()
	_append_walk(m, to_node, false)
	path_index = 0
	_route_topology = tunnels.topology
	_goal = tunnels.node_m(to_node)
	_goal_node = -1
	_start_trip_record()
	_start_leg(path_tunnel[0])
	return true


func task_haul_out(m: int, to: Vector2) -> bool:
	"""For a task, standing in its bore: carry a load out (the carry clip, when this creature has one) the cheapest way
	through what it may walk to mouth `m`, up there, and on over the ground to `to`, where the task's arrived() is
	called (a dig crew's basket to its heap, decision 0211). False, nothing changed, when there is no way to `m`."""
	var tunnels := _space.tunnels
	var mouth_node: int = tunnels.mouth_node[m]
	var slot_index := _travel_slot
	carrying = can_carry()
	var end := _end_toward(slot_index, mouth_node)
	if end < 0:
		carrying = false
		return false
	var node: int = tunnels.end_node(slot_index, end == 1)
	path.clear()
	path_tunnel.clear()
	path.append(tunnels.node_m(node))
	path_tunnel.append(TunnelRouterScript.leg_code(slot_index, end == 0))
	if node != mouth_node:
		_append_walk(m, node, true)
	path.append(to)
	path_tunnel.append(TunnelRouterScript.SURFACE_LEG)
	path_index = 0
	_route_topology = tunnels.topology
	_goal = to
	_goal_node = -1
	_replans = 0
	_travel_for_task = false
	_start_trip_record()
	_start_travel(slot_index, _travel_m, tunnels.length_m(slot_index) if end == 1 else 0.0)
	return true


func task_play(clip_name: StringName) -> void:
	"""For a task: play this clip (idle when the creature lacks it) at its own speed."""
	_set_clip(clip_name if has_clip(clip_name) else CLIP_IDLE, 1.0)


func task_face(point: Vector2, delta: float) -> void:
	"""For a task: turn toward `point` at the on-the-spot rate."""
	if point.distance_to(position) > 1e-3:
		yaw = turn_toward(yaw, yaw_of(point - position), SPOT_TURN_RATE * delta)


# --- the night (see THE NIGHT) --------------------------------------------------------------------

func task_stroll_to(point: Vector2, delta: float) -> bool:
	"""For a task, on a room's floor: turn toward `point` and walk straight to it at walk speed, the walk clip at its
	stride (a turn past STOP_TO_TURN_ANGLE on the spot first, stepping in place). True once there."""
	var to := point - position
	var gap := to.length()
	if gap <= ARRIVE_RADIUS_M:
		_set_clip(CLIP_IDLE, 1.0)
		return true
	yaw = turn_toward(yaw, yaw_of(to), SPOT_TURN_RATE * delta)
	if absf(angle_difference(yaw, yaw_of(to))) > STOP_TO_TURN_ANGLE:
		_set_clip(CLIP_WALK, SHUFFLE_CLIP_SPEED)
		return false
	position += to / gap * minf(walk_speed * delta, gap)
	_set_clip(CLIP_WALK, gait_rate())
	_space.move_resident(index, position)
	return false


func task_hold_below() -> void:
	"""For a task, underground: stand where it is in its bore heading neither way, so walkers step aside and pass
	(see `task_stand_in_bore`), however the task moves it about a room's floor."""
	var slot_index: int = _space.resident_tunnel[index]
	_space.set_in_bore(index, slot_index if slot_index >= 0 else _travel_slot, _travel_m, 0)


func task_lie(middle: Vector2, face_yaw: float, top_y: float) -> void:
	"""For a task: lie down with the body's middle at `middle`, facing `face_yaw` (head toward -Z of that frame, as the
	sleep clip lies), on a surface `top_y` high -- a mattress, or a floor. Asleep: the sleep clip when it has one."""
	yaw = face_yaw
	position = middle - lie_middle_m.rotated(-face_yaw)
	lying = true
	lie_top_y_m = top_y
	_set_clip(CLIP_SLEEP if has_clip(CLIP_SLEEP) else CLIP_IDLE, 1.0)
	_space.move_resident(index, position)


func task_rise(stand_at: Vector2) -> void:
	"""For a task: get up, and stand at `stand_at`, idle."""
	lying = false
	position = stand_at
	_set_clip(CLIP_IDLE, 1.0)
	_space.move_resident(index, position)


func task_go_indoors(inside: bool) -> void:
	"""For a task: into a building (not drawn, and off the walking surface, so it stands in nobody's way) or back out
	of it."""
	indoors = inside
	_space.set_underground(index, inside or underground)


# --- the water's crossings (see THE WATER) --------------------------------------------------------

func _enter_crossing(code: int) -> void:
	"""At a crossing's end: hand the walk to the water's hook until it stands at the far end."""
	state = State.CROSS
	_space.crossings.begin_leg(self, TunnelRouterScript.crossing_row(code), TunnelRouterScript.leg_reversed(code))


func _step_cross(delta: float) -> void:
	"""One step across the crossing; at its far end, go on as from a tunnel's mouth."""
	if _space.crossings.step_leg(self, delta):
		_end_cross()


func _end_cross() -> void:
	"""Off the crossing, standing on its far end: out of the water, and on along the route."""
	water_out()
	state = State.WALK
	_go_on_from_mouth()


func interrupt_to_task(new_task: TaskScript) -> void:
	"""THE WATER'S EMERGENCY ONLY (see THE WATER): take this resident off whatever it is doing -- a
	crossing leg included, where it stands -- and hand it to `new_task` at once, with no walk first.
	Any earlier task is cancelled and any slot or line given up; the route is dropped."""
	if state == State.CROSS:
		_space.crossings.abandon_leg(self)
	release_slot()
	_leave_dig()
	_leave_line()
	_drop_task()
	_forget_step_out()
	_idle_on_surface = false
	carrying = false
	path.clear()
	path_tunnel.clear()
	path_index = 0
	task = new_task
	order = ORDER_TASK
	_goal = position
	state = State.TASK
	new_task.arrived(self)


func leg_speed() -> float:
	"""The pace a crossing is walked at on land or a deck: the carry's own with a load, else the walk's,
	times the weather's surface speed (m/s)."""
	var base := _carry_speed if carrying and _carry_speed > 0.0 else walk_speed
	return base * float(_space.tunnels.surface_permille) / float(TunnelRules.PERMILLE)


func leg_clip() -> StringName:
	"""The clip a crossing is walked with (the carry, with a load)."""
	return _locomotion_clip()


func leg_clip_rate() -> float:
	"""The walking clip's rate for `leg_speed()`: the feet stay planted (see WEATHER AND LANTERNS)."""
	return stride_rate() * float(_space.tunnels.surface_permille) / float(TunnelRules.PERMILLE)


func water_clip(name: StringName, speed: float) -> void:
	"""For the water: play clip `name` (idle when this creature lacks it) at `speed`."""
	_set_clip(name if has_clip(name) else CLIP_IDLE, speed)


func water_place(at: Vector2, y_m: float, face_yaw: float) -> void:
	"""For the water: stand (or swim) at `at`, `y_m` from the ground datum, facing `face_yaw`."""
	position = at
	ground_y_m = y_m
	yaw = face_yaw
	_space.move_resident(index, at)


func water_in() -> void:
	"""Into the water: off the walking surface (CastSpace.set_in_water), drawn swimming."""
	if in_water:
		return
	in_water = true
	_space.set_in_water(index, true)


func water_out() -> void:
	"""Out of the water, back on the walking surface."""
	if not in_water:
		return
	in_water = false
	_space.set_in_water(index, false)
