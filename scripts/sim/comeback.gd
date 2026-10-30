class_name Comeback
extends RefCounted
## Loop idea 8 (docs/LOOP_IDEAS.md): comeback valves. A bad hour should be pressure with a way back, not a death spiral.
##
## The first valve is the windfall: when the pilot is nearly broke and has no job on, the next board dealt at a strip carries one
## honest, well-paid cargo run to a sound strip nearby. No random draw (a fixed job, the nearest field), so it moves no RNG stream; at
## most one per WINDFALL_EVERY_S. Off for the Python replays (Switches.PARITY), whose boards never had it.

static var ENABLED := true

const WINDFALL_BELOW := 1500  ## $ in hand under which a pilot counts as broke
const WINDFALL_EVERY_S := 1800.0  ## at most one windfall in this long
const WINDFALL_LB := 180.0
const WINDFALL_BASE := 1800  ## $: enough for fuel and a margin on any aircraft
const WINDFALL_PER_KM := 150


## A legitimate crate run from `here` to the nearest other strip of 500 m or more that is not foreign; null if there is none.
static func windfall_job(here: Airfield, airfields: Array) -> Jobs.Job:
	var dest: Airfield = null
	var best := INF
	for af in airfields:
		if af.code == here.code or af.kind == "foreign" or af.length < 500.0:
			continue
		var d := Jobs._dist_km(here, af)
		if d < best:
			best = d
			dest = af
	if dest == null:
		return null
	var jid := Jobs.new_id()
	var crate := Loadout.Item.new(Jobs.new_id(), "Machine parts", "cargo", WINDFALL_LB, jid)
	return Jobs.Job.new(jid, "Windfall: machine parts -> %s" % dest.name, "cargo", here.code, dest.code, [crate],
		WINDFALL_BASE + int(best * WINDFALL_PER_KM), {"notes": "A friend of a friend needs parts flown, no questions about your bank balance. Honest work that pays well: one per bad stretch."})
