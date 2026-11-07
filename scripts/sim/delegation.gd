class_name Delegation
extends RefCounted
## Delegated deliveries (L-5; docs/EMPIRE_SIMULATION_SPEC.md sections 4 and 6, A5; D-10, D-66): a job the organisation has taken
## is handed to one of its hired pilots, who flies it off-screen and delivers it through the same adapter as a flown delivery
## (`Session.deliver(job, af, by, mode)`), so the money and the goods change exactly as if the player had flown it. The only
## difference is D-10's fee: delegating a flight costs FEE_SHARE of the job's pay, one `delegation_fee` transfer from the safe to
## `outside:crew`, paid when the job is handed over.
##
## `delegate_job {job_id, pilot}`: the job leaves the aircraft (its cargo goes with the pilot), the pilot is busy until it lands
## (the great-circle leg at CRUISE_MS plus TURNAROUND_S), then the delivery is made at its destination with `by` the pilot's id and
## `mode: "delegated"`. Plain cargo and hot loads only: an Agency flight, a defector, our own load, a stash job or a gun run stays
## the player's. The flight itself is not simulated and draws nothing: a delegated run is safe in v1 (its risk is the pilot's
## own runs, Payroll). Saved (the runs under way, as saved jobs). Behind ENABLED (in the parity set).

static var ENABLED := true

const FEE_SHARE := 0.1
const CRUISE_MS := 70.0
const TURNAROUND_S := 600.0

var sess
var runs: Array = []  ## {job: Jobs.Job, pilot: id, due: t}


func _init(sess_) -> void:
	sess = sess_


## Why `job` can't be handed over, or "".
static func refusal(job) -> String:
	if job.agency:
		return "The Company only trusts you with its flights."
	if job.defector:
		return "The defector flies with you or not at all."
	if job.own_good != "":
		return "Our own load goes in our own aircraft."
	if job.stash != "":
		return "A stash job needs the crew at the strip."
	if not job.weapons.is_empty():
		return "Guns don't go with a contract pilot."
	return ""


func fee_of(job) -> int:
	return int(round(float(job.payout) * FEE_SHARE))


## Hand active job `job_id` to free pilot `pilot_id`. "" or why not.
func delegate(job_id: int, pilot_id: String) -> String:
	if sess.payroll == null:
		return "No payroll in this game: hire a pilot first."
	var job = Py.first(sess.active_jobs, func(j): return int(j.id) == job_id)
	if job == null:
		return "That job isn't ours."
	var why := refusal(job)
	if why != "":
		return why
	var p = sess.payroll.get_worker(pilot_id)
	if p == null or str(p.get("role", "")) != "pilot" or str(p.get("outfit", "org")) != "org":
		return "No pilot of ours by that name."
	if str(p.status) != "free":
		return "%s is busy." % str(p.name)
	var fee := fee_of(job)
	if sess.money < fee:
		return "A contract run costs $%s." % Py.money(fee)
	var from: Airfield = World.airfield(sess.location) if sess.location != "" else null
	var to := World.airfield(str(job.dest))
	if to == null:
		return "Nowhere to deliver it."
	if fee > 0:
		sess.move_money(-fee, "outside:crew", "delegation_fee")
	sess.active_jobs.erase(job)
	sess.loadout.remove_job(job.id)
	p.status = "assigned"
	p.assigned = "run-%d" % int(job.id)
	var leg := PyMath.hypot(to.x - from.x, to.y - from.y) if from != null else 0.0
	runs.append({"job": job, "pilot": pilot_id, "due": float(sess.time) + leg / CRUISE_MS + TURNAROUND_S})
	sess.say("%s takes '%s' to %s (-$%s)." % [str(p.name), job.title, to.name, Py.money(fee)])
	sess.bus.emit("job_delegated", sess.time, "", ["runner"], {"job_id": job.id, "by": pilot_id, "fee": fee})
	return ""


func update() -> void:
	if runs.is_empty():
		return
	for r in runs.duplicate():
		if float(sess.time) < float(r.due):
			continue
		runs.erase(r)
		var af := World.airfield(str(r.job.dest))
		if af != null:
			sess.deliver(r.job, af, str(r.pilot), "delegated")
		if sess.payroll != null:
			sess.payroll.release([str(r.pilot)])


func capture() -> Array:
	return runs.map(func(r): return {"job": Jobs.job_to_save(r.job), "pilot": r.pilot, "due": r.due})


func restore(a: Array) -> void:
	runs = []
	for row in a:
		if row is Dictionary and row.get("job") is Dictionary:
			runs.append({"job": Jobs.job_from_save(row.job), "pilot": str(row.get("pilot", "")), "due": float(row.get("due", 0.0))})
