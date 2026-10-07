class_name People
extends RefCounted
## Physical NPCs, step 6: the payroll's people. Every worker who is not already a body somewhere else
## (a soldier is one of his squad's men, a driver is the one in the truck) is an Agent here, standing
## at the post the payroll gives him: a lookout at his stash, a dealer on his corner, everyone else
## round the organisation's base. A new hire starts at the base and goes to his post - on foot if it is
## near, in a car along the road if it is not - so you can see him arrive; someone hired long ago (a
## game that was just loaded) is already there.
##
## The payroll stays the authority: this follows it, as a squad's men follow the squad (GroundWar).
## A lookout counts from the moment he is posted, not the moment he arrives, so nothing in the
## balance moves; the roster says where he is ("heading out to the boathouse, 3.2 km to go").
## Behind Agent.ENABLED.

const WALK_M := 600.0  ## a post further than this is driven to
const SETTLED_S := 600.0  ## hired longer ago than this: already at the post when first seen

var sess
var bodies := {}  ## worker id -> Agent
var _requested := {}
var halted := {}  ## current route obstructed: retain the last valid position
var blocked := {}  ## worker id -> failed physical travel reason, independent of payroll work
var _access: SiteAccess
var _post := {}  ## worker id -> the post key the body is at or on its way to


func _init(sess_) -> void:
	sess = sess_


## [key, where] for a worker's post, or null when he is a body somewhere else (or away on a run).
func post_of(w: Dictionary) -> Variant:
	var role := str(w.get("role", ""))
	var a := str(w.get("assigned", ""))
	var o := str(w.outfit)
	if str(w.get("status", "")) == "assigned":
		if a.begins_with("truck-") or a.begins_with("cash-"):
			return null  # he is the driver in the truck
		if sess.payroll.squads.has(a):
			return null  # he is one of the squad's men
		if a.begins_with("stash-") and sess.stash_net != null:
			var st = sess.stash_net.get_stash(a.trim_prefix("stash-"))
			if st != null:
				return [a, _spot(Vector2(st.x, st.y), w, 3.0)]
		elif a.begins_with("corner-"):
			var c: Array = Economy.centre(a.trim_prefix("corner-"))
			return [a, _spot(Vector2(c[0], c[1]), w, 3.0)]
		elif role in ["pilot", "mule"]:
			return null  # away on a run
	return ["hq", _spot(_hq(o), w, 2.5)]


func _hq(o: String) -> Vector2:
	var h = sess.world.map.hqs.get({"org": "org", "rival": "rival"}.get(o, "org"))
	return Vector2(h.x, h.y) if h != null else Vector2.ZERO


## The organisation's base as a place to start from: the road node nearest its door (the HQ's own point
## is inside the building).
func _base(o: String) -> Vector2:
	return _street(_hq(o))


## The nearest point on the road network to `p`.
func _street(p: Vector2) -> Vector2:
	if sess.ground != null and sess.ground.graph.road_nodes > 0:
		return sess.ground.graph.nodes[sess.ground.graph.nearest(p)]
	return p


## Where a worker stands near `p`: in the street, a few metres along the road from its nearest node, on
## one side or the other, `gap` metres from the man before - so a crew waits in a line down the road and
## nobody is inside a building. Fixed by his id; consecutive ids hash to consecutive numbers, which is
## what spreads them.
func _spot(p: Vector2, w: Dictionary, gap: float) -> Vector2:
	var h: int = str(w.id).hash()
	var g: RoadGraph = sess.ground.graph if sess.ground != null else null
	if g == null or g.road_nodes == 0:
		var ang := float(h % 100000) * 2.39996323  # the golden angle: no two on the same bearing
		return p + Vector2(cos(ang), sin(ang)) * 5.0
	var n := g.nearest(p)
	var at: Vector2 = g.nodes[n]
	var dir := Vector2.RIGHT
	if not g.adj[n].is_empty():
		dir = (g.nodes[g.adj[n][0][0]] - at).normalized()
	var side := dir.orthogonal() * (1.5 if h % 2 == 0 else -1.5)
	return at + dir * (3.0 + float((h / 2) % 6) * gap) + side


func update(dt: float) -> void:
	if not Agent.ENABLED or sess.payroll == null:
		return
	var graph: RoadGraph = sess.ground.graph if sess.ground != null else null
	var alive := {}
	for w in sess.payroll.workers:
		if not str(w.get("status", "")) in ["free", "assigned"]:
			continue
		var spot = post_of(w)
		if spot == null:
			continue
		var id := str(w.id)
		alive[id] = true
		var key: String = spot[0]
		var at: Vector2 = spot[1]
		var body: Agent = bodies.get(id)
		if body == null:
			var arrived: bool = sess.time - float(w.get("hired_at", 0.0)) > SETTLED_S
			var from: Vector2 = at if arrived else _base(str(w.outfit))
			body = Agent.new(id, "foot", from.x, from.y)
			bodies[id] = body
			if arrived:
				_post[id] = key
				_requested[id] = key
		if _requested.get(id, "") != key:
			_requested[id] = key
			var reason := _send(body, at, graph, str(w.outfit))
			if reason == "":
				_post[id] = key
				blocked.erase(id)
				halted.erase(id)
			else:
				blocked[id] = reason
		if not halted.has(id) and not body.idle():
			var remaining := _remaining(body, body.speed_ms() * maxf(dt, 0.0))
			for i in remaining.size() - 1:
				var reason := _access.segment_reason(remaining[i], remaining[i + 1], body.kind == "car") if _access != null else ""
				if reason != "":
					blocked[id] = reason
					halted[id] = true
					break
		if not halted.has(id): body.update(dt, graph)
	for id in bodies.keys():
		if not alive.has(id):
			bodies.erase(id)
			_post.erase(id)
			_requested.erase(id)
			blocked.erase(id)
			halted.erase(id)


func _send(body: Agent, at: Vector2, graph: RoadGraph, faction := "org") -> String:
	if _access == null: _access = SiteAccess.new(sess.world, sess.world.site_records())
	var driving := body.pos().distance_to(at) > WALK_M
	var route: Dictionary
	if driving:
		if graph == null: return "No vehicle travel network."
		var penalty: Callable = sess.ground._penalty(faction) if sess.ground != null and GroundWar.SMART_ROUTES else Callable()
		route = _access.checked_vehicle_route(graph, body.pos(), at, penalty)
	else:
		route = _access.path(body.pos(), at)
	if not route.reachable: return str(route.reason)
	body.clear()
	body.kind = "car" if driving else "foot"
	body.speed = 0.0
	body.queue(Agent.Task.new("go", at, 0.0, route.points))
	return ""


## Metres a worker still has to travel to his post (0: there, or no body).
func left_m(id: String) -> float:
	var b: Agent = bodies.get(id)
	return b.left_m() if b != null else 0.0


## What the 3D side draws: one row per body.
func draw_list() -> Array:
	var out := []
	for w in sess.payroll.workers:
		var b: Agent = bodies.get(str(w.id))
		if b == null:
			continue
		var moving := not b.idle()
		var row := {"id": w.id, "x": snappedf(b.x, 0.1), "y": snappedf(b.y, 0.1), "faction": w.outfit, "moving": moving,
			"car": moving and b.kind == "car"}
		if str(w.outfit) == "org":
			row.merge({"name": str(w.name), "role": str(w.role), "assignment": str(w.get("assigned", "")),
				"travel": "blocked" if blocked.has(str(w.id)) else ("travelling" if moving else "at post"),
				"blocked_reason": str(blocked.get(str(w.id), ""))})
		out.append(row)
	return out

## Slice only future travel; past route sections never move a worker backward.
static func _remaining(body: Agent, metres := INF) -> PackedVector2Array:
	var points := PackedVector2Array([body.pos()])
	var end := minf(body.s + metres, RoadGraph.length(body.route))
	var along := 0.0
	for i in body.route.size() - 1:
		along += body.route[i].distance_to(body.route[i + 1])
		if along <= body.s: continue
		if along >= end:
			points.append(RoadGraph.along(body.route, end))
			break
		points.append(body.route[i + 1])
	return points

static func _encode(points: PackedVector2Array) -> Array:
	var out := []
	for point in points: out.append([point.x, point.y])
	return out

static func _decode(values: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for value in values:
		if value is Array and value.size() == 2:
			var point := Vector2(float(value[0]), float(value[1]))
			if point.is_finite(): out.append(point)
	return out

func capture() -> Dictionary:
	var rows := []
	for id in bodies:
		var worker = sess.payroll.get_worker(str(id))
		if worker == null or str(worker.status) not in ["free", "assigned"] or post_of(worker) == null: continue
		var body: Agent = bodies[id]
		var tasks := []
		for task: Agent.Task in body.tasks:
			tasks.append({"kind": task.kind, "x": task.at.x, "y": task.at.y, "dur": task.dur, "route": _encode(task.route)})
		rows.append({"id": id, "kind": body.kind, "x": body.x, "y": body.y, "speed": body.speed, "route": _encode(body.route),
			"s": body.s, "tasks": tasks, "working": body._working, "held": body._held, "carry": body._carry, "busy": body.busy_s,
			"post": str(_post.get(id, "")), "requested": str(_requested.get(id, "")), "blocked": str(blocked.get(id, "")), "halted": halted.has(id)})
	return {"v": 1, "bodies": rows}

func restore(data: Dictionary) -> void:
	bodies.clear()
	_post.clear()
	_requested.clear()
	blocked.clear()
	halted.clear()
	_access = SiteAccess.new(sess.world, sess.world.site_records())
	for row in data.get("bodies", []):
		if not row is Dictionary: continue
		var id := str(row.get("id", ""))
		var worker = sess.payroll.get_worker(id)
		if worker == null or str(worker.status) not in ["free", "assigned"] or post_of(worker) == null: continue
		var position := Vector2(float(row.get("x", 0.0)), float(row.get("y", 0.0)))
		if not position.is_finite(): continue
		var kind := str(row.get("kind", "foot"))
		var body := Agent.new(id, kind if kind in ["foot", "car"] else "foot", position.x, position.y)
		body.speed = float(row.get("speed", 0.0))
		body.route = _decode(row.get("route", []))
		body.s = clampf(float(row.get("s", 0.0)), 0.0, RoadGraph.length(body.route))
		body._working = float(row.get("working", 0.0))
		body._held = float(row.get("held", 0.0))
		body._carry = float(row.get("carry", 0.0))
		body.busy_s = float(row.get("busy", 0.0))
		for task in row.get("tasks", []):
			body.tasks.append(Agent.Task.new(str(task.kind), Vector2(task.x, task.y), float(task.dur), _decode(task.get("route", []))))
		bodies[id] = body
		_post[id] = str(row.get("post", ""))
		_requested[id] = str(row.get("requested", ""))
		if str(row.get("blocked", "")) != "": blocked[id] = str(row.blocked)
		if bool(row.get("halted", false)): halted[id] = true
		if not body.idle():
			var future := _remaining(body)
			for i in future.size() - 1:
				var reason := _access.segment_reason(future[i], future[i + 1], body.kind == "car")
				if reason != "":
					blocked[id] = "Saved travel blocked: " + reason
					halted[id] = true
					break
