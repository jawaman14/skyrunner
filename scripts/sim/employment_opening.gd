class_name EmploymentOpening
extends RefCounted
## Optional new-story prelude. No chapter renumbering or legacy-save rewrites.
const EMPLOYER := "Costa Brava Air Services"
const AIRCRAFT := "c172p"
const PURCHASE_PRICE := 18000  # provisional career-only used-aircraft price; needs pacing playtest
const TITLES := ["On the payroll", "An unusual customer", "No more pretending"]
const BRIEFINGS := [
	"Costa Brava Air Services hired you to fly its Cessna. It belongs to the company, not you. Start with ordinary supplies between San Telmo and Valle Verde. Complete two deliveries; check fuel and loading before departure.",
	"The charter business is struggling. A customer pays for sealed cases and asks you not to discuss the contents. This first request is suspicious, but carries no contraband flag. Complete the flight; the company is changing.",
	"The manager finally tells you what the next load is: marijuana. This is smuggling, with police consequences. The customer uses an unpoliced strip, not the scheduled airport charter route. Check the destination and radar information before departure. There is no legitimate-only branch of this story. You can postpone the flight, but completing it is required to continue."
]
var stage := 0
var delivered := 0
var next_serial := 1
var last_completed := 0
var loaner := true

func active() -> bool:
	return stage < TITLES.size()

func chapter() -> Campaign.Chapter:
	return Campaign.Chapter.new(0, 1979, TITLES[stage], BRIEFINGS[stage], [], [],
		[Campaign.Objective.new("employer_deliveries", "Complete employer deliveries", 2 if stage == 0 else 1)])

func guidance(s) -> String:
	return "J: employer job board. Deliver the assigned load to its named airfield. Fuel, cargo and police rules still apply.\nAircraft: %s. First ownership: $%s at an aircraft dealer; active jobs must be finished or dropped. Savings: $%s." % [
		"employer-owned Cessna" if loaner else "your own aircraft", Py.money(PURCHASE_PRICE), Py.money(s.money)]

func board(s, code: String) -> Array:
	if not s.active_jobs.is_empty():
		return []
	var origin := World.airfield(code)
	var dest = null
	for field in s.world.airfields:
		if field.code != code and field.code == ("VAL" if code == "HAR" else "HAR"):
			dest = field
	if dest == null:
		for field in s.world.airfields:
			if field.code != code and field.kind in ["hub", "regional"]:
				dest = field
				break
	if stage == 2:
		# Teach a deliberate access choice, not a mandatory customs-airport gamble.
		dest = null
		var best := INF
		for field in s.world.airfields:
			if field.code == code or field.police or field.kind not in ["bush", "shady"] or field.length < 400:
				continue
			var distance: float = Jobs._dist_km(origin, field)
			if distance < best:
				best = distance
				dest = field
	if dest == null:
		return []
	var jid := Jobs.new_id()
	var hot := stage == 2
	var cargo := Loadout.Item.new(Jobs.new_id(), ["Food supplies", "Sealed charter cases", "Bale"][stage], "cargo", 120.0, jid, {"hot": hot})
	var dist: float = Jobs._dist_km(origin, dest)
	# Reuse existing cargo/contraband pay formulas; no separate wage multiplier.
	var pay := int((900 + 120 * 9 + dist * 120) * Jobs._difficulty(dest)) if hot else int((120 + 120 * 1.6 + dist * 120 * 0.09) * Jobs._difficulty(dest))
	var job := Jobs.Job.new(jid, "%s: %s → %s" % [EMPLOYER, TITLES[stage], dest.name], "contraband" if hot else "cargo", code, dest.code, [cargo], pay,
		{"notes": BRIEFINGS[stage], "employer_stage": stage, "employer_serial": next_serial})
	next_serial += 1
	return [job]

func record(data: Dictionary) -> bool:
	var serial := int(data.get("employer_serial", 0))
	if not active() or int(data.get("employer_stage", -1)) != stage or serial <= last_completed or serial >= next_serial:
		return false
	last_completed = serial
	delivered += 1
	if delivered >= (2 if stage == 0 else 1):
		stage += 1
		delivered = 0
		return true
	return false

func to_dict() -> Dictionary:
	return {"stage": stage, "delivered": delivered, "next_serial": next_serial, "last_completed": last_completed, "loaner": loaner}

static func from_dict(data: Dictionary) -> EmploymentOpening:
	var opening := EmploymentOpening.new()
	opening.stage = clampi(int(data.get("stage", 0)), 0, TITLES.size())
	opening.delivered = clampi(int(data.get("delivered", 0)), 0, 1)
	opening.last_completed = maxi(0, int(data.get("last_completed", 0)))
	opening.next_serial = maxi(opening.last_completed + 1, int(data.get("next_serial", 1)))
	opening.loaner = bool(data.get("loaner", true))
	return opening
