extends TestCase
## Delegated deliveries (L-5): a hired pilot flies a job of ours through the same delivery adapter, for D-10's fee. A5: a flown and
## a delegated delivery give equal economic state, but for the one fee transfer.


func _sess() -> Session:
	var s := Session.new({"seed": 4, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES,
		"trade": true, "payroll": true, "logistics": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	s.money = 50000
	return s


func after_each() -> void:
	World.use_map(0)


func _job(s: Session) -> Jobs.Job:
	var it := Loadout.Item.new(Jobs.new_id(), "Crate", "cargo", 20.0, 0, {})
	var job := Jobs.Job.new(Jobs.new_id(), "Test run", "cargo", "FRM", "HAR", [it], 1500, {})
	it.job_id = job.id
	s.active_jobs.append(job)
	s.loadout.add(it)
	return job


func _pilot(s: Session) -> String:
	for p in s.payroll.of("org", "pilot", "free"):
		return str(p.id)
	var w: Dictionary = s.payroll._person("org", "pilot")  # one off the hiring hall's list (its draws: the same in both runs)
	w.status = "free"
	s.payroll.workers.append(w)
	return str(w.id)


## The economic projection (spec A5): balances, lots and the transfers as (from, to, amount, reason), without provenance.
func _projection(s: Session, rows: Array) -> Dictionary:
	var moves := rows.map(func(r): return "%s>%s %.2f %s" % [r.from, r.to, float(r.amount), r.reason])
	moves.sort()
	var bal := {}
	for r in rows:
		bal[r.from] = snappedf(float(bal.get(r.from, 0.0)) - float(r.amount), 0.01)
		bal[r.to] = snappedf(float(bal.get(r.to, 0.0)) + float(r.amount), 0.01)
	var lots := []
	for id in s.inventory.lots:
		lots.append("%s %s %.2f" % [s.inventory.lots[id].at, s.inventory.lots[id].good, float(s.inventory.lots[id].lb)])
	lots.sort()
	return {"moves": moves, "balances": bal, "lots": lots}


func test_a_flown_and_a_delegated_delivery_change_the_same_things() -> void:
	var a := _sess()
	var b := _sess()
	_pilot(a)
	var pid := _pilot(b)
	var ja := _job(a)
	var jb := _job(b)
	var n_a := a.ledger.log.size()
	var n_b := b.ledger.log.size()
	a.deliver(ja, World.airfield("HAR"), "seat:pilot", "flown")
	var r: Array = b.command(Roles.BOSS, "delegate_job", {"job_id": jb.id, "pilot": pid})
	check(r[0], "handed over: %s" % [r])
	check(b.active_jobs.is_empty() and b.loadout.items.is_empty(), "off our books and out of the aircraft")
	check_eq(b.payroll.get_worker(pid).status, "assigned", "the pilot is busy")
	b.time = float(b.delegation.runs[0].due)
	b.delegation.update()
	check(b.delegation.runs.is_empty(), "landed")
	check_eq(b.payroll.get_worker(pid).status, "free", "and the pilot is free again")
	var rows_a: Array = a.ledger.log.slice(n_a)
	var rows_b: Array = b.ledger.log.slice(n_b)
	var fees := rows_b.filter(func(x): return x.reason == "delegation_fee")
	check_eq(fees.size(), 1, "exactly one fee")
	if fees.size() == 1:
		check(fees[0].from == "org:safe" and fees[0].to == "outside:crew", "from the safe to the crew")
		check_near(float(fees[0].amount), 150.0, 0.01, "10% of the pay")
	var pa := _projection(a, rows_a)
	var pb := _projection(b, rows_b.filter(func(x): return x.reason != "delegation_fee"))
	check_eq(pb.moves, pa.moves, "A5: the same transfers")
	check_eq(pb.balances, pa.balances, "the same balances, recomputed without the fee")
	check_eq(pb.lots, pa.lots, "the same goods where they were")
	a.dispose()
	b.dispose()


func test_the_event_says_who_and_how() -> void:
	var s := _sess()
	var pid := _pilot(s)
	var job := _job(s)
	var got := []
	s.bus.subscribe("job_delivered", func(e): got.append(e))
	s.command(Roles.BOSS, "delegate_job", {"job_id": job.id, "pilot": pid})
	s.time = float(s.delegation.runs[0].due)
	s.delegation.update()
	check_eq(got.size(), 1, "delivered")
	if got.size() == 1:
		check_eq(str(got[0].data.by), pid, "by the pilot")
		check_eq(str(got[0].data.mode), "delegated", "delegated")
	check_eq(s._delivery_mode, "flown", "and the next delivery is the seat's again")
	s.dispose()


func test_some_jobs_stay_ours() -> void:
	var s := _sess()
	var pid := _pilot(s)
	var job := _job(s)
	job.agency = true
	var r: Array = s.command(Roles.BOSS, "delegate_job", {"job_id": job.id, "pilot": pid})
	check(not r[0] and str(r[1]).contains("Company"), "an Agency flight: %s" % [r])
	job.agency = false
	s.money = 10
	r = s.command(Roles.BOSS, "delegate_job", {"job_id": job.id, "pilot": pid})
	check(not r[0] and str(r[1]).contains("costs"), "the fee: %s" % [r])
	s.dispose()


func test_a_run_under_way_is_saved() -> void:
	var s := _sess()
	var pid := _pilot(s)
	var job := _job(s)
	s.command(Roles.BOSS, "delegate_job", {"job_id": job.id, "pilot": pid})
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	check(d.has("delegated"), "saved")
	var r := _sess()
	StrategicSave.restore(r, d)
	check_eq(r.delegation.runs.size(), 1, "the run comes back")
	check_eq(int(r.delegation.runs[0].job.id), job.id, "the same job")
	s.dispose()
	r.dispose()
