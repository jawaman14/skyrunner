class_name Agent
extends RefCounted
## A worker's body on the map: a position, a route, and a queue of tasks done
## in order. First step of the physical-NPC design rule (docs/ROADMAP.md,
## second wave - "every worker, driver, soldier and dealer has to be
## somewhere"). Nothing else in the sim creates or reads an Agent yet: this
## sits behind ENABLED and is exercised only by its own tests until the next
## step (drivers and hauled cargo in Logistics) wires it in.
##
## A task is "go to `at`, then spend `dur` seconds doing `kind` there" (dur 0:
## doing it IS arriving - a walk with nothing to do at the end). "car" agents
## follow the road graph; "foot" agents go straight there - off-road pathing
## is its own later step (docs/ROADMAP.md's "Pathfinding").

static var ENABLED := false

const SPEED := {"foot": 1.4, "car": 12.0}  ## m/s: a brisk walk; city driving


class Task:
	## `kind` is a label the Agent itself never acts on beyond arriving and
	## waiting out `dur` - whoever queues the task (Payroll, Logistics, ...)
	## supplies the meaning and reads it back off update()'s return value.
	var kind: String
	var at: Vector2
	var dur: float

	func _init(kind_: String, at_: Vector2, dur_ := 0.0) -> void:
		kind = kind_
		at = at_
		dur = dur_


var id: String
var kind: String  ## foot | car
var x := 0.0
var y := 0.0
var route := PackedVector2Array()
var s := 0.0  ## metres travelled along route
var tasks: Array = []  ## Task queue; tasks[0] is the one under way
var _working := 0.0  ## seconds spent on the current task since arriving


func _init(id_: String, kind_: String, x_: float, y_: float) -> void:
	id = id_
	kind = kind_
	x = x_
	y = y_


func pos() -> Vector2:
	return Vector2(x, y)


func idle() -> bool:
	return tasks.is_empty()


## Adds a task to the end of the queue; a new leg is routed only once it
## becomes the one under way (queuing several keeps the plan, not the path,
## until each is reached - the road graph can change underfoot otherwise).
func queue(task: Task) -> void:
	tasks.append(task)
	if tasks.size() == 1:
		_route_to(task.at)


func clear() -> void:
	tasks.clear()
	route = PackedVector2Array()
	s = 0.0
	_working = 0.0


func _route_to(to: Vector2, graph: RoadGraph = null) -> void:
	route = graph.route(pos(), to) if graph != null and kind == "car" else PackedVector2Array([pos(), to])
	s = 0.0


## Advances one tick. Returns the task's `kind` the moment it finishes (arrived
## and dur spent), else "" - at most one finishes per call even if dt is large,
## so a caller polling every frame never misses one.
func update(dt: float, graph: RoadGraph = null) -> String:
	if tasks.is_empty():
		return ""
	var t: Task = tasks[0]
	if route.is_empty():
		_route_to(t.at, graph)
	var total := RoadGraph.length(route)
	if s < total:
		s = minf(total, s + SPEED[kind] * dt)
		var p := RoadGraph.along(route, s)
		x = p.x
		y = p.y
		if s < total:
			return ""
	_working += dt
	if _working < t.dur:
		return ""
	_working = 0.0
	tasks.pop_front()
	route = PackedVector2Array()
	if not tasks.is_empty():
		_route_to(tasks[0].at, graph)
	return t.kind
