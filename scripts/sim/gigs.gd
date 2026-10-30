class_name Gigs
extends RefCounted
## Side gigs at the strips (owner, 30 Oct: make the first chapters less bare): short legitimate jobs with a flying twist, each a few
## checkpoints to fly through before landing at the strip named.
##   photo     aerial survey: three points inland, under 600 m above the ground, then back to the strip it came from
##   banner    a banner tow down the beach: four points along the coast, under 150 m, then back
##   flour     a flour-sack "drop" for a fair: one low pass under 60 m over the target, then on to a nearby strip
## One gig on each board dealt at a strip (not the island, not foreign strips). Checkpoints are flown in order. A gig lands only when
## all are done: until then the strip it ends at holds it ("the client wants the shots first").
##
## Own RNG stream (seed + 181), behind Gigs.ENABLED in Switches.PARITY (the replays' boards never had them). Active jobs are not saved,
## so neither is a gig's progress.

static var ENABLED := true

const KINDS := ["photo", "banner", "flour"]
const SPEC := {
	"photo": {"title": "Aerial photos", "n": 3, "radius": 450.0, "max_agl": 600.0, "range": [5000.0, 11000.0], "base": 700, "per_km": 45},
	"banner": {"title": "Banner tow along the beach", "n": 4, "radius": 400.0, "max_agl": 150.0, "range": [3000.0, 12000.0], "base": 650, "per_km": 40},
	"flour": {"title": "Flour-sack pass for the fair", "n": 1, "radius": 300.0, "max_agl": 60.0, "range": [3000.0, 9000.0], "base": 550, "per_km": 50},
}


## One gig for the board at `af`, or null when no points can be found. `rng`: the gig stream.
static func gig_for(world: World, af: Airfield, airfields: Array, rng: PyRandom) -> Jobs.Job:
	var kind: String = KINDS[rng.randint(0, KINDS.size() - 1)]
	var sp: Dictionary = SPEC[kind]
	var pts := []
	if kind == "banner":
		pts = _coast_run(world, af, rng, int(sp.n))
	else:
		for k in int(sp.n):
			var p := _land_point(world, af, rng, sp.range)
			if p.is_empty():
				return null
			pts.append(p)
	if pts.size() < int(sp.n):
		return null
	var dest := af
	if kind == "flour":  # on to the nearest other strip
		var best := INF
		for other in airfields:
			if other.code != af.code and other.kind != "foreign":
				var d := PyMath.hypot(other.x - pts[0][0], other.y - pts[0][1])
				if d < best:
					best = d
					dest = other
	var km := 0.0
	var prev := [af.x, af.y]
	for p in pts:
		km += PyMath.hypot(p[0] - prev[0], p[1] - prev[1]) / 1000.0
		prev = p
	km += PyMath.hypot(dest.x - prev[0], dest.y - prev[1]) / 1000.0
	var jid := Jobs.new_id()
	var crate := Loadout.Item.new(Jobs.new_id(), {"photo": "Camera case", "banner": "Banner rig", "flour": "Flour sacks"}[kind], "cargo",
		{"photo": 40.0, "banner": 60.0, "flour": 90.0}[kind], jid)
	var job := Jobs.Job.new(jid, "Gig: %s (%d point%s) -> %s" % [sp.title, pts.size(), "" if pts.size() == 1 else "s", dest.name], "gig",
		af.code, dest.code, [crate], int(sp.base) + int(km * float(sp.per_km)),
		{"notes": "Fly the points in order, under %d m above the ground, then land at %s." % [int(sp.max_agl), dest.name]})
	job.checkpoints = pts.map(func(p): return [p[0], p[1], float(sp.radius), float(sp.max_agl)])
	return job


static func _land_point(world: World, af: Airfield, rng: PyRandom, rng_m: Array) -> Array:
	for tries in 24:
		var a := rng.uniform(0.0, TAU)
		var r := rng.uniform(float(rng_m[0]), float(rng_m[1]))
		var x := af.x + sin(a) * r
		var y := af.y + cos(a) * r
		if absf(x) < World.HALF - 1500.0 and absf(y) < World.HALF - 1500.0 and not world.is_water(x, y):
			return [x, y]
	return []


## Points along the shore near the strip: find the coast on a random bearing, then step along it, each point pulled back onto the land
## side of the waterline (the coast curves), 250 m in from the water.
static func _coast_run(world: World, af: Airfield, rng: PyRandom, n: int) -> Array:
	for tries in 12:
		var a := rng.uniform(0.0, TAU)
		var seaward := Vector2(sin(a), cos(a))
		var first = _shore_from(world, Vector2(af.x, af.y) + seaward * 1000.0, seaward, 12000.0)
		if first == null:
			continue
		var along := Vector2(seaward.y, -seaward.x)
		var pts := [[first.x, first.y]]
		var at: Vector2 = first
		while pts.size() < n:
			var guess := at + along * 1500.0
			var start := guess - seaward * 2500.0  # from inland, walk out to the water again
			var next = _shore_from(world, start, seaward, 5000.0)
			if next == null or absf(next.x) > World.HALF - 1000.0 or absf(next.y) > World.HALF - 1000.0:
				break
			pts.append([next.x, next.y])
			at = next
		if pts.size() == n:
			return pts
	return []


## Walking from `p` along `dir`: the last land point 250 m short of the first water within `reach`, or null.
static func _shore_from(world: World, p: Vector2, dir: Vector2, reach: float):
	if world.is_water(p.x, p.y):
		return null
	var d := 0.0
	while d < reach:
		var q := p + dir * d
		if world.is_water(q.x, q.y):
			var back := p + dir * maxf(0.0, d - 250.0)
			return back if not world.is_water(back.x, back.y) else null
		d += 125.0
	return null


## Each frame in the air: the next checkpoint of each gig is reached when the aircraft is inside its radius and low enough.
## Returns the messages to say.
static func progress(jobs: Array, x: float, y: float, agl: float) -> Array:
	var out := []
	for j in jobs:
		if j.checkpoints.is_empty() or j.visited >= j.checkpoints.size():
			continue
		var c: Array = j.checkpoints[j.visited]
		if PyMath.hypot(x - float(c[0]), y - float(c[1])) <= float(c[2]) and agl <= float(c[3]):
			j.visited += 1
			out.append(("%s: point %d of %d done." % [j.title.get_slice(" (", 0), j.visited, j.checkpoints.size()]) if j.visited < j.checkpoints.size()
				else "%s: all points done - now land at %s." % [j.title.get_slice(" (", 0), World.airfield(j.dest).name])
	return out


static func done(j) -> bool:
	return j.checkpoints.is_empty() or j.visited >= j.checkpoints.size()
