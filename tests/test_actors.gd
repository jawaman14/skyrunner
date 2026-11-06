extends TestCase
## Actors (F-5, docs/EMPIRE_SIMULATION_SPEC.md section 6): who does a thing, {org, role, person}; `command` is a shim over
## `command_as`; events raised by a command carry its actor and org; a delivery says who made it and how.


func _sess() -> Session:
	var s := Session.new({"seed": 4, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES,
		"trade": true, "payroll": true, "logistics": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func test_a_seat_is_its_sides_org_and_the_seat_as_the_person() -> void:
	check_eq(Actor.for_role(Roles.PILOT), {"org": "org", "role": Roles.PILOT, "person": "seat:pilot"}, "the pilot is the organisation's")
	check_eq(Actor.org_of(Roles.CONTROLLER), "police", "the controller is the police's")
	check_eq(Actor.refusal(Actor.for_role(Roles.BOSS), "hire_worker"), "", "the boss may hire")


func test_command_as_refuses_with_a_reason() -> void:
	var s := _sess()
	var r := s.command_as(Actor.of("rival", Roles.BOSS, "rival:boss"), "hire_worker", {"kind": "dealer"})
	check(not r[0] and str(r[1]).contains("can't act as"), "Los Cuervos can't use the organisation's boss seat: %s" % [r])
	r = s.command_as(Actor.of("org", Roles.PILOT, "seat:pilot"), "hire", {})
	check(not r[0] and str(r[1]).contains("can't do"), "a role keeps its permissions: %s" % [r])
	r = s.command_as(Actor.of("", Roles.PILOT), "set_flaps", {})
	check(not r[0] and str(r[1]).contains("no organisation"), "an actor with no org is refused: %s" % [r])
	s.dispose()


func test_the_shim_gives_the_same_result_and_tags_the_events() -> void:
	var s := _sess()
	var seen := []
	s.bus.subscribe("*", func(e): seen.append(e))
	var a: Array = s.command(Roles.BOSS, "hire_worker", {"kind": "dealer"})
	var b: Array = s.command_as(Actor.for_role(Roles.BOSS), "hire_worker", {"kind": "dealer"})
	check_eq(a[0], b[0], "the shim and command_as agree")
	var tagged := seen.filter(func(e): return e.actor.get("role", "") == Roles.BOSS)
	if not seen.is_empty():
		check(not tagged.is_empty() and tagged.all(func(e): return e.org == "org"), "events raised by the command carry its actor and org")
	check(s.bus.actor.is_empty(), "and the bus forgets the actor afterwards")
	s.bus.emit("weather", s.time, "", ["runner"], {})
	check(seen.back().actor.is_empty() and seen.back().org == "", "the world's own events have no actor")
	s.dispose()


func test_a_flown_delivery_says_who_and_how() -> void:
	var s := _sess()
	var got := []
	s.bus.subscribe("job_delivered", func(e): got.append(e))
	var af := World.airfield("FRM")
	var it := Loadout.Item.new(Jobs.new_id(), "Crate", "cargo", 20.0, 0, {})
	var job := Jobs.Job.new(Jobs.new_id(), "Test", "cargo", "HAR", "FRM", [it], 500, {})
	s.active_jobs.append(job)
	s.loadout.add(it)
	s._complete_delivery(job, af)
	check(not got.is_empty(), "delivered")
	if not got.is_empty():
		check_eq(str(got[0].data.by), "seat:pilot", "by the pilot's seat")
		check_eq(str(got[0].data.mode), "flown", "flown")
		check_eq(got[0].org, "org", "for the organisation")
	s.dispose()
