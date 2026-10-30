extends TestCase
## Loop idea 5: the deal moves mid-flight. Benny calls once per airdrop; answering moves the drop and the boat, doubles the pay and
## puts a cutter on picket; declining keeps the old point.


func after_each() -> void:
	DealMoves.ENABLED = true
	World.use_map(0)


func _flying_with_drop() -> Array:
	var s := Session.new({"seed": 23, "location": "HAR"})
	s.police.frozen = true
	var drop := Maritime.random_drop_point(s.world, PyRandom.new(), s.maritime.cove)
	var job := Jobs.airdrop_job(World.airfield("HAR"), drop, PyRandom.new(), 4)
	s.accept_job(job)
	var af := World.airfield("HAR")
	s.spawn_airborne(af.x, af.y, 90.0, 600.0, 110.0)  # far from the drop, in the air
	s.deal_moves.live = true
	s.deal_moves.rng.seed(1)
	return [s, job]


func _ring(s: Session) -> void:
	for i in 60:  # up to an hour of minutes: a call comes long before
		s.deal_moves.update(60.0)
		if not s.phone_calls.pending().is_empty():
			return


func test_benny_calls_once_and_answering_moves_the_drop() -> void:
	var r := _flying_with_drop()
	var s: Session = r[0]
	var job: Jobs.Job = r[1]
	var old: Array = job.drop_point.duplicate()
	var pay := job.payout
	_ring(s)
	var calls := s.phone_calls.pending()
	check_eq(calls.size(), 1, "the phone rings")
	var cutters_before := s.maritime.boats.filter(func(b): return b.kind == "cutter").size()
	check(s.command(Roles.PILOT, "phone_answer", {"id": calls[0].id})[0], "answered")
	check(PyMath.hypot(float(job.drop_point[0]) - old[0], float(job.drop_point[1]) - old[1]) > 7000.0, "the drop moved")
	check(s.world.is_water(job.drop_point[0], job.drop_point[1]), "still at sea")
	check_eq(job.payout, pay * 2, "pay doubles")
	check_eq(s.maritime.boats.filter(func(b): return b.kind == "cutter").size(), cutters_before + 1, "a cutter on picket")
	for i in 30:
		s.deal_moves.update(60.0)
	check(s.phone_calls.pending().is_empty(), "only once per job")
	s.dispose()


func test_no_offer_once_the_bales_are_in_the_water() -> void:
	var r := _flying_with_drop()
	var s: Session = r[0]
	var job: Jobs.Job = r[1]
	for it in s.loadout.items.values().filter(func(i): return i.job_id == job.id):
		s.loadout.remove_item(it.id)
	_ring(s)
	check(s.phone_calls.pending().is_empty(), "nothing aboard: no deal to move")
	s.dispose()


func test_no_deal_once_the_boat_has_gone_home() -> void:
	var r := _flying_with_drop()
	var s: Session = r[0]
	var job: Jobs.Job = r[1]
	if job.boat_id:
		s.maritime.boat(job.boat_id).state = "running"
	_ring(s)
	check(s.phone_calls.pending().is_empty() or not job.boat_id, "the boat is heading home: no call")
	s.dispose()


func test_the_cutter_holds_its_picket() -> void:
	var r := _flying_with_drop()
	var s: Session = r[0]
	_ring(s)
	s.command(Roles.PILOT, "phone_answer", {"id": s.phone_calls.pending()[0].id})
	var c = s.maritime.boats.filter(func(b): return b.kind == "cutter").back()
	for i in 600:  # ten minutes of maritime updates
		s.maritime.update(1.0, [])
	check(c.goal != null and c.picket_s > 0.0, "still on station after ten minutes")
	check(s.world.is_water(c.x, c.y), "and at sea")
	s.dispose()


func test_declining_keeps_the_old_point() -> void:
	var r := _flying_with_drop()
	var s: Session = r[0]
	var job: Jobs.Job = r[1]
	var old: Array = job.drop_point.duplicate()
	_ring(s)
	s.command(Roles.PILOT, "phone_decline", {"id": s.phone_calls.pending()[0].id})
	check_eq(job.drop_point, old, "the old point stands")
	s.dispose()


func test_no_call_without_a_person_flying_or_in_the_parity_replays() -> void:
	var r := _flying_with_drop()
	var s: Session = r[0]
	s.deal_moves.live = false
	_ring(s)
	check(s.phone_calls.pending().is_empty(), "the bots never get the call")
	s.deal_moves.live = true
	DealMoves.ENABLED = false
	_ring(s)
	check(s.phone_calls.pending().is_empty(), "off for parity")
	s.dispose()
