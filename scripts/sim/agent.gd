class_name Agent
extends RefCounted
## A worker's body on the map: a position, a route, and a queue of tasks done
## in order. The physical-NPC design rule (docs/ROADMAP.md, second wave -
## "every worker, driver, soldier and dealer has to be somewhere"). Step 1
## was this class on its own; step 2 puts a driver in every stash truck
## (StashNet.Truck.start_agent): the agent's progress is the truck's, and the
## truck is delivered when the agent arrives, not when a timer runs out.
##
## A task is "go to `at`, then spend `dur` seconds doing `kind` there" (dur 0:
## doing it IS arriving - a walk with nothing to do at the end). A task can
## carry its own `route` (a planned road); without one a "car" agent follows
## the road graph if it is given one, and a "foot" agent goes straight there -
## off-road pathing is its own later step (docs/ROADMAP.md's "Pathfinding").
##
## Behind ENABLED so the parity tests can turn it off; with it on, a truck
## takes exactly as long as its timer did (tests/test_agent.gd).

static var ENABLED := true

const SPEED := {"foot": 1.4, "car": 12.0}  ## m/s: a brisk walk; city driving


class Task:
	## `kind` is a label the Agent itself never acts on beyond arriving and
	## waiting out `dur` - whoever queues the task (Payroll, Logistics, ...)
	## supplies the meaning and reads it back off update()'s return value.
	var kind: String
	var at: Vector2
	var dur: float
	var route := PackedVector2Array()  ## a planned route; empty: the agent picks its own

	func _init(kind_: String, at_: Vector2, dur_ := 0.0, route_ := PackedVector2Array()) -> void:
		kind = kind_
		at = at_
		dur = dur_
		route = route_


var id: String
var kind: String  ## foot | car
var speed := 0.0  ## m/s; 0 = SPEED[kind]
var x := 0.0
var y := 0.0
var route := PackedVector2Array()
var s := 0.0  ## metres travelled along route
var tasks: Array = []  ## Task queue; tasks[0] is the one under way
var _working := 0.0  ## seconds spent on the current task since arriving
var _held := 0.0  ## seconds the agent is stuck for (pulled over, waiting out a fight)
var _carry := 0.0  ## time left over when a task finished mid-tick, spent on the next one


func _init(id_: String, kind_: String, x_: float, y_: float) -> void:
	id = id_
	kind = kind_
	x = x_
	y = y_


func pos() -> Vector2:
	return Vector2(x, y)


func idle() -> bool:
	return tasks.is_empty()


func speed_ms() -> float:
	return speed if speed > 0.0 else float(SPEED[kind])


## The task under way, or null.
func current() -> Task:
	return tasks[0] if not tasks.is_empty() else null


## Seconds spent on the current task since arriving (loading, guarding, ...).
func working_s() -> float:
	return _working


## Metres still to travel on the current leg (0 when working or idle).
func left_m() -> float:
	return maxf(0.0, RoadGraph.length(route) - s) if not tasks.is_empty() else 0.0


## Adds a task to the end of the queue; a new leg is routed only once it
## becomes the one under way (queuing several keeps the plan, not the path,
## until each is reached - the road graph can change underfoot otherwise).
func queue(task: Task) -> void:
	tasks.append(task)
	if tasks.size() == 1:
		_route_to(task)


func clear() -> void:
	tasks.clear()
	route = PackedVector2Array()
	s = 0.0
	_working = 0.0
	_held = 0.0
	_carry = 0.0


## Stuck for `seconds` more: nothing moves or gets done until they pass.
func hold(seconds: float) -> void:
	_held += seconds


func _route_to(task: Task, graph: RoadGraph = null) -> void:
	if task.route.size() >= 2:
		route = task.route
	elif graph != null and kind == "car":
		route = graph.route(pos(), task.at)
	else:
		route = PackedVector2Array([pos(), task.at])
	s = 0.0


## Advances one tick. Returns the task's `kind` the moment it finishes (arrived
## and dur spent), else "" - at most one finishes per call even if dt is large,
## so a caller polling every frame never misses one.
func update(dt: float, graph: RoadGraph = null) -> String:
	if tasks.is_empty():
		return ""
	dt += _carry
	_carry = 0.0
	if _held > 0.0:
		var stuck := minf(_held, dt)
		_held -= stuck
		dt -= stuck
		if dt <= 0.0:
			return ""
	var t: Task = tasks[0]
	if route.is_empty():
		_route_to(t, graph)
	var total := RoadGraph.length(route)
	if s < total:
		var need := (total - s) / speed_ms()
		if dt < need:
			s += speed_ms() * dt
			var p := RoadGraph.along(route, s)
			x = p.x
			y = p.y
			return ""
		dt -= need  # arrived with some of this tick to spare: it counts towards the work
		s = total
		var end := RoadGraph.along(route, s)
		x = end.x
		y = end.y
	_working += dt
	if _working < t.dur:
		return ""
	_carry = _working - t.dur  # what's left over starts the next task
	_working = 0.0
	tasks.pop_front()
	route = PackedVector2Array()
	if not tasks.is_empty():
		_route_to(tasks[0], graph)
	return t.kind
