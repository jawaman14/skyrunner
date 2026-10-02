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
		if _post.get(id, "") != key:
			_post[id] = key
			_send(body, at, graph)
		body.update(dt, graph)
	for id in bodies.keys():
		if not alive.has(id):
			bodies.erase(id)
			_post.erase(id)


func _send(body: Agent, at: Vector2, graph: RoadGraph) -> void:
	body.clear()
	body.kind = "car" if body.pos().distance_to(at) > WALK_M else "foot"
	body.speed = 0.0
	body.queue(Agent.Task.new("go", at))
	if body.kind == "car" and graph != null:
		body.route = graph.route(body.pos(), at)
		body.s = 0.0


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
		out.append({"id": w.id, "x": snappedf(b.x, 0.1), "y": snappedf(b.y, 0.1), "faction": w.outfit, "moving": moving,
			"car": moving and b.kind == "car"})
	return out
