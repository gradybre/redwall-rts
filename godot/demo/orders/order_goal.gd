extends RefCounted
## A STANDING ORDER'S GOAL (decision 0711): how one kind of good is measured and which existing work fulfils it -- one
## goal per kind (standing_kinds.gd KIND_*), read by the book (standing_orders.gd). The goal never decides a job's
## outcome: it reads the owner's own figures and opens a job through the owner's own board, exactly as an order with
## nobody selected does, so the work board (work_board.gd) lists and claims it like any other. Presentation only.
##
## The base answers for a goal with nothing to do; each kind overrides what it supports.

const WorkIds := preload("res://demo/work/work_ids.gd")
const Kinds := preload("res://demo/orders/standing_kinds.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const NOTHING: String = "nothing can be done for it here"

## Kinds.KIND_* of this goal.
var kind: int = -1
## WorkIds.SOURCE_* of the jobs it opens.
var source: int = -1


func measure(_item: int) -> int:
	"""The good now, in its kind's unit (milli-U or milli-days)."""
	return 0


func target(amount: int) -> int:
	"""What the order keeps the good at (its amount; the winter's Firewood: the projection)."""
	return amount


func own_rule() -> bool:
	"""Whether the goal says itself when work is wanted (`wanted`) instead of the book's amount and band."""
	return false


func wanted(_item: int) -> bool:
	"""With `own_rule`: whether a job should stand now."""
	return false


func urgent(_item: int) -> bool:
	"""Whether its jobs belong in the work board's food/fuel bucket now (GDD §5.3 bucket 2: the reserve under two
	days; systems_architecture.md's declared-versus-effective bucket)."""
	return false


func key_of(_row: int) -> int:
	"""The job's identity on its row (the owner's serial)."""
	return -1


func live(_row: int, _key: int) -> bool:
	"""Whether the job it opened on `row` with `key` is still on its owner's board."""
	return false


func output_of(_row: int, _item: int) -> int:
	"""What the live job on `row` will still bring into store (REQ-SET-098's committed in-progress output)."""
	return 0


func raise_into(_item: int, _tracked: Callable, _out: IntMath.IntResult) -> String:
	"""Open (or adopt) one job that raises the good; its row into `out`. "" when one was, else why not in the player's
	words. `tracked(source, key) -> bool` says whether some order already holds a job (never adopted twice)."""
	return NOTHING
