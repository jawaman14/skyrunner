extends TestCase
var _session: Session
var _agent := true

func before_each() -> void:
	_agent = Agent.ENABLED
	Agent.ENABLED = true

func after_each() -> void:
	if _session != null: _session.dispose()
	_session = null
	Agent.ENABLED = _agent
	World.use_map(0)

func _setup() -> String:
	_session = Session.new({"seed": 12, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"payroll": true, "ground_war": true})
	_session.payroll.ai.org = false
	_session.payroll.ai.rival = false
	var worker: Dictionary = _session.payroll._person("org", "accountant")
	worker.status = "free"
	_session.payroll.workers.append(worker)
	_session.payroll.people.bodies[worker.id] = Agent.new(worker.id, "foot", 123.4, 567.8)
	return worker.id

func test_snapshot_exposes_only_own_live_workers_and_current_assignment() -> void:
	var id := _setup()
	var rival: Dictionary = _session.payroll._person("rival", "accountant")
	rival.status = "free"
	_session.payroll.workers.append(rival)
	_session.payroll.people.bodies[rival.id] = Agent.new(rival.id, "foot", 900, 1000)
	var worker: Dictionary = _session.payroll.get_worker(id)
	for role in Roles.ALL:
		var rows: Array = Snapshot.build(_session, role).get("people", [])
		if Roles.side(role) == "runner":
			check_eq(rows.size(), 1, role + " sees only own worker")
			if rows.size() != 1: continue
			check_eq(rows[0].id, id)
			check_eq(rows[0].name, worker.name)
			check_eq(rows[0].doing, _session.payroll.doing(worker))
			check_near(rows[0].x, 123.4, 0.01)
		else:
			check(rows.is_empty(), role + " has no criminal-worker positions")
	worker.status = "jailed"
	check(Snapshot.build(_session, Roles.BOSS).people.is_empty(), "stale body hidden before next tick")
	worker.status = "dead"
	check(Snapshot.build(_session, Roles.BOSS).people.is_empty())
	worker.status = "assigned"
	worker.assigned = "truck-test"
	check(Snapshot.build(_session, Roles.BOSS).people.is_empty(), "driver is not a second worker marker")
	_session.payroll.squads["squad-test"] = {}
	worker.assigned = "squad-test"
	check(Snapshot.build(_session, Roles.BOSS).people.is_empty(), "squad member has only the squad body")
	worker.role = "pilot"
	worker.assigned = "run-test"
	check(Snapshot.build(_session, Roles.BOSS).people.is_empty(), "away pilot has no payroll marker")
	worker.status = "free"
	worker.assigned = ""
	Agent.ENABLED = false
	check(Snapshot.build(_session, Roles.BOSS).people.is_empty(), "disabled bodies do not leave markers")

func test_markers_are_read_only_and_follow_the_people_layer() -> void:
	var id := _setup()
	var body: Agent = _session.payroll.people.bodies[id]
	var before: Vector2 = body.pos()
	var rows := _session.payroll.people.map_list("org")
	rows[0].x = 9999
	rows[0].name = "changed"
	check_eq(body.pos(), before)
	check_near(_session.payroll.people.map_list("org")[0].x, before.x, 0.01)
	var map := StationMap.new()
	map.snap = Snapshot.build(_session, Roles.BOSS)
	check_eq(map.visible_items("people").size(), 1)
	map.set_layer("people", false)
	check(map.visible_items("people").is_empty())
	map.set_layer("operations", false)
	map.set_layer("people", true)
	check_eq(map.visible_items("people").size(), 1)
	map.free()
