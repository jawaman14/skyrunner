extends TestCase
## D-36 (DESIGN 85): the AI police and Los Cuervos act only on what a human in their seat would see. A truck of ours is known to
## them when one of their squads or their HQ can see it; to the police also when they tail it or suspect the house it runs to; to
## Los Cuervos when they have heard of that house (heat 20). Checkpoints and ambushes go only on trucks they know of. Off, every truck.


class FixedRng extends PyRandom:
	var v := 0.0

	func _init(v_ := 0.0) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	World.use_map(0)
	GroundWar.FAIR_SIGHT = true


func _sess() -> Session:
	var s := Session.new({"seed": 12, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"payroll": true, "ground_war": true, "trade": true, "logistics": true})
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.payroll.ai["rival"] = false
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	s.money = 100000
	for q in s.ground.squads.duplicate():
		s.ground.squads.erase(q)  # nobody on the street: only what the test puts there
	return s


## A van from the stash nearest our HQ to the farthest, and the stash it runs to.
func _van(s: Session) -> Array:
	var lg: Logistics = s.logistics
	var live: Array = s.stash_net.live()
	var hq := s.ground.hq("rival")
	live.sort_custom(func(a, b): return Vector2(a.x, a.y).distance_to(hq) > Vector2(b.x, b.y).distance_to(hq))
	var a := str(live[0].id)  # far from Los Cuervos
	var b := str(live[1].id)
	for st in live:
		st.heat = 0.0
	lg.add(a, "marijuana", 200.0, "farm")
	check_eq(lg.send(a, b, "marijuana", 100.0), "", "a van")
	var t = s.stash_net.trucks[0]
	return [t, s.stash_net.get_stash(b)]


func _far_from_both_hqs(s: Session, t) -> bool:
	var p: Array = t.pos(s.time)
	var at := Vector2(p[0], p[1])
	return s.ground.hq("rival").distance_to(at) >= GroundWar.SIGHT_M and s.ground.hq("police").distance_to(at) >= GroundWar.SIGHT_M


func test_los_cuervos_know_a_truck_they_see_or_a_house_they_have_heard_of() -> void:
	var s := _sess()
	var v := _van(s)
	var t = v[0]
	if not _far_from_both_hqs(s, t):
		check(true, "the van starts within sight of an HQ on this map: nothing to test")
		s.dispose()
		return
	check(not s.ground.truck_known_to("rival", t), "unseen, to a quiet house: they don't know")
	v[1].heat = 25.0
	check(s.ground.truck_known_to("rival", t), "word on the street about that house: they do")
	v[1].heat = 0.0
	var p: Array = t.pos(s.time)
	var q = s.ground.recruit("rival", "foot", Vector2(p[0], p[1]) + Vector2(300, 0), false)
	check(q is GroundWar.Squad, "a squad of theirs nearby")
	check(s.ground.truck_known_to("rival", t), "seen: they know")
	GroundWar.FAIR_SIGHT = false
	s.ground.squads.erase(q)
	check(s.ground.truck_known_to("rival", t), "off: they know every truck")
	s.dispose()


func test_the_police_know_what_they_tail_or_suspect() -> void:
	var s := _sess()
	var v := _van(s)
	var t = v[0]
	if not _far_from_both_hqs(s, t):
		check(true, "the van starts within sight of an HQ on this map: nothing to test")
		s.dispose()
		return
	if s.investigation != null:
		s.investigation.cases.erase(str(v[1].id))
	check(not s.ground.truck_known_to("police", t), "no case on the house, nobody watching: unknown")
	s.ground.tails[t.job_id] = ["P-x", str(v[1].id)]
	check(s.ground.truck_known_to("police", t), "a tail: known")
	s.ground.tails.erase(t.job_id)
	s.dispose()


func test_no_checkpoint_on_a_truck_they_dont_know_of() -> void:
	var s := _sess()
	var v := _van(s)
	var t = v[0]
	if not _far_from_both_hqs(s, t):
		check(true, "the van starts within sight of an HQ on this map: nothing to test")
		s.dispose()
		return
	if s.investigation != null:
		s.investigation.cases.erase(str(v[1].id))
	s.ground.recruit("police", "car", s.ground.hq("police"), false)
	s.ground.recruit("police", "car", s.ground.hq("police"), false)
	s.ground.rng = FixedRng.new(0.0)  # every draw says yes
	s.ground._think_police()
	check(not s.ground.squads.any(func(q): return int(q.order.get("job_id", -1)) == t.job_id), "unknown: no checkpoint on its road")
	s.dispose()
