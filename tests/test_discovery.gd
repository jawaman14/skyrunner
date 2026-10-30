extends TestCase
## Hidden strips (owner, 30 Oct): a story game's shady strips start off the chart and are found by flying low near them or by a job.


func after_each() -> void:
	Discovery.ENABLED = true
	World.use_map(0)


func _story() -> Session:
	var s := Session.new({"seed": 9, "location": "HAR", "career": true})
	Story.new(0).attach(s)
	return s


func test_shady_strips_start_hidden_and_are_found_low_and_close() -> void:
	var s := _story()
	var shady: Array = s.world.airfields.filter(func(a): return a.kind == "shady")
	check(not shady.is_empty(), "the island has shady strips")
	for af in shady:
		check(not s.discovery.is_known(af.code), "%s off the chart" % af.code)
	check(s.discovery.is_known("HAR"), "the airport is on it")
	var target: Airfield = shady[0]
	s.spawn_airborne(target.x + 1500.0, target.y, 0.0, 1200.0, 100.0)
	s.discovery.update(1.0)
	check(not s.discovery.is_known(target.code), "too high to see it")
	s.spawn_airborne(target.x + 1500.0, target.y, 0.0, 200.0, 100.0)
	s.discovery.update(1.0)
	check(s.discovery.is_known(target.code), "low and close: found")
	s.dispose()


func test_a_job_there_gives_the_coordinates_and_found_strips_are_saved() -> void:
	var s := _story()
	var shady: Array = s.world.airfields.filter(func(a): return a.kind == "shady")
	var job := Jobs.Job.new(Jobs.new_id(), "A crate", "cargo", "HAR", shady[0].code, [], 100)
	s.active_jobs.append(job)
	s.discovery.update(1.0)
	check(s.discovery.is_known(shady[0].code), "a job there reveals it")
	var data := StrategicSave.capture(s)
	var t := _story()
	StrategicSave.restore(t, data)
	check(t.discovery.is_known(shady[0].code), "still found after a load")
	if shady.size() > 1:
		check(not t.discovery.is_known(shady[1].code), "the others still hidden")
	s.dispose()
	t.dispose()


func test_a_loaded_story_keeps_its_chart_and_the_switch_turns_it_off() -> void:
	var s := Session.new({"seed": 9, "location": "HAR", "career": true})
	var loaded := Story.from_dict(Story.new(0).to_dict())
	loaded.attach(s)
	for af in s.world.airfields:
		check(s.discovery.is_known(af.code), "a loaded story does not hide %s again" % af.code)
	s.dispose()
	Discovery.ENABLED = false
	var t := _story()
	for af in t.world.airfields:
		check(t.discovery.is_known(af.code), "switched off: %s on the chart" % af.code)
	t.dispose()


func test_no_story_hides_nothing() -> void:
	var s := Session.new({"seed": 9, "location": "HAR"})
	for af in s.world.airfields:
		check(s.discovery.is_known(af.code), "%s on the chart in open play" % af.code)
	s.dispose()
