extends TestCase
## Goal markers (owner, 30 Oct): where the story's next required goal can be done.


func after_each() -> void:
	World.use_map(0)


func test_no_story_no_marks() -> void:
	var s := Session.new({"seed": 5, "location": "HAR"})
	check_eq(GoalMarks.of(s), [], "open mode: nothing to point at")
	s.dispose()


func test_the_employed_opening_points_at_the_board_then_the_delivery() -> void:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "career": true})
	Story.new_employed().attach(s)
	var marks := GoalMarks.of(s)
	check_eq(marks.size(), 1, "one mark")
	check(marks.size() == 1 and "job board" in str(marks[0].label), "the employer's board first: %s" % [marks])
	s.refresh_board("HAR")
	var job: Jobs.Job = s.boards["HAR"][0]
	s.command(Roles.PILOT, "accept_job", {"job_id": job.id})
	marks = GoalMarks.of(s)
	var dest := World.airfield(job.dest)
	check(marks.size() == 1 and absf(float(marks[0].x) - dest.x) < 1.0 and "Deliver" in str(marks[0].label), "then where it goes")
	s.dispose()


func test_chapter_one_points_at_grass_work() -> void:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "career": true})
	Story.new(0).attach(s)
	var marks := GoalMarks.of(s)
	check(not marks.is_empty(), "the first goal (grass to the stash houses) has places")
	for m in marks:
		var af: Airfield = s.world.nearest_airfield(float(m.x), float(m.y))[0]
		check_eq(af.kind, "bush", "a bush strip: %s" % m.label)
	check(marks.size() <= GoalMarks.MAX_MARKS, "a handful, not the whole map")
	s.dispose()
