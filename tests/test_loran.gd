extends TestCase
## The LORAN-C receiver: a cheap first upgrade (owner, 30 Oct: make the first chapters less bare).


func after_each() -> void:
	World.use_map(0)


func test_the_set_is_cheap_and_sold_everywhere() -> void:
	var s := Session.new({"seed": 2, "location": "FRM", "features": []})
	check(Session.GEAR.has("loran") and int(Session.GEAR.loran[0]) <= 1000, "a first upgrade a new pilot can afford")
	s.money = 1000
	check(s.command(Roles.PILOT, "buy_gear", {"name": "loran"})[0], "bought at a bush strip with no features on")
	check(s.gear.has("loran"), "fitted")
	s.dispose()


func test_it_points_at_the_waypoint_then_the_job() -> void:
	var s := Session.new({"seed": 2, "location": "HAR"})
	check_eq(Hud.loran_line(s, null), "", "no set, no readout")
	s.gear["loran"] = true
	var af := World.airfield("HAR")
	s.spawn_airborne(af.x, af.y, 0.0, 500.0, 100.0)
	check_eq(Hud.loran_line(s, null), "", "nowhere to point")
	var line := Hud.loran_line(s, Vector2(af.x, af.y + 10000.0))
	check(line.begins_with("LORAN  WPT  000°") and "10.0 km" in line, "due north, 10 km: %s" % line)
	s.refresh_board("HAR")
	var job: Jobs.Job = s.boards["HAR"].filter(func(j): return not j.is_airdrop())[0]
	s.active_jobs.append(job)
	check(Hud.loran_line(s, null).begins_with("LORAN  " + job.dest), "the job's strip: %s" % Hud.loran_line(s, null))
	s.dispose()
