extends TestCase
## Side gigs (owner, 30 Oct): short legitimate jobs with checkpoints to fly before landing.


func after_each() -> void:
	Gigs.ENABLED = true
	World.use_map(0)


func _gig(s: Session, kind: String) -> Jobs.Job:
	for i in 60:  # draw until the stream gives this kind
		var j := Gigs.gig_for(s.world, World.airfield("HAR"), s.world.airfields, s.gig_rng)
		if j != null and j.title.begins_with("Gig: " + str(Gigs.SPEC[kind].title)):
			return j
	return null


func test_every_kind_can_be_dealt_with_sound_points() -> void:
	var s := Session.new({"seed": 8, "location": "HAR"})
	for kind in Gigs.KINDS:
		var j := _gig(s, kind)
		check(j != null, "%s dealt" % kind)
		if j == null:
			continue
		check_eq(j.checkpoints.size(), int(Gigs.SPEC[kind].n), "%s points" % kind)
		for c in j.checkpoints:
			check(not s.world.is_water(float(c[0]), float(c[1])), "%s point over land" % kind)
		check(not j.hot() and j.payout > 0, "honest, paid")
	s.dispose()


func test_a_gig_lands_only_when_its_points_are_flown() -> void:
	var s := Session.new({"seed": 8, "location": "HAR"})
	var j := _gig(s, "photo")
	s.accept_job(j)
	s.log.airborne = true
	s._arrive(World.airfield(j.dest), s.state)
	check(s.active_jobs.has(j), "no points flown: the client waits")
	var c: Array = j.checkpoints[0]
	check(Gigs.progress([j], float(c[0]) + 9999.0, float(c[1]), 100.0).is_empty(), "far away: nothing")
	check(Gigs.progress([j], float(c[0]), float(c[1]), 2000.0).is_empty(), "too high: nothing")
	for k in j.checkpoints.size():
		c = j.checkpoints[k]
		check_eq(Gigs.progress([j], float(c[0]), float(c[1]), 100.0).size(), 1, "point %d" % (k + 1))
	var money := s.money
	s.log.airborne = true
	s._arrive(World.airfield(j.dest), s.state)
	check(not s.active_jobs.has(j) and s.money > money, "all flown: paid on landing")
	s.dispose()


func test_a_gig_can_be_taken_during_the_employer_opening_and_goes_to_remote_crews() -> void:
	var s := Session.new({"seed": 8, "map_seed": MapCity.SEED, "location": "HAR", "career": true})
	Story.new_employed().attach(s)
	s.refresh_board("HAR")
	var gigs: Array = s.boards["HAR"].filter(func(j): return j.kind == "gig")
	check_eq(gigs.size(), 1, "a gig beside the employer's job")
	if gigs.size() == 1:
		check_eq(s.accept_job_reason(gigs[0]), "", "and it can be taken")
		s.accept_job(gigs[0])
		var snap: Dictionary = Snapshot._job(s, gigs[0])
		check_eq((snap.points as Array).size(), gigs[0].checkpoints.size(), "its points go to the remote stations")
	s.dispose()


func test_boards_carry_one_gig_and_none_with_the_switch_off() -> void:
	var s := Session.new({"seed": 8, "location": "HAR"})
	s.refresh_board("VAL")
	check_eq(s.boards["VAL"].filter(func(j): return j.kind == "gig").size(), 1, "one gig on a board")
	Gigs.ENABLED = false
	s.refresh_board("VAL")
	check(s.boards["VAL"].filter(func(j): return j.kind == "gig").is_empty(), "off for the parity replays")
	s.dispose()
