class_name Takeover
extends RefCounted
## The takeover (D-09, D-78, D-35; docs/DESIGN.md section 80): in the story's Cocaine Cowboys chapter Los Cuervos kill Rafa. The
## player hears of it (never sees it), and half of what he built survives:
##
##   stashes   half the houses, the least known to the task force (the others go to Los Cuervos with what is in them)
##   crew      half the people on the payroll (the rest walk; soldiers in a squad and drivers on the road are not counted)
##   trucks    the ones parked at home (every truck on the road that hour is lost with its load and its driver)
##   cash      a quarter of the street money lying in the stashes (the pilot's own safe is the pilot's, and is not touched)
##
## It comes at the first Los Cuervos incident of the chapter (a firefight one of their squads is in, or a hijack of ours), or
## GRACE_S into the chapter when the streets stay quiet. From then the boss's desk is the player's; flying, driving and the
## ground stay open as before (D-79). Los Cuervos' standing with us goes to nothing.
##
## Own RNG stream (seed + 199): ties between equally known stashes, and who of the crew walks; drawn once, when it happens.
## Saved. Behind ENABLED (in the parity set): off, Rafa lives and nothing is lost. A game without the story never has one, and a
## game first seen already past the chapter (a save from before this, a chapter picked from the menu) is taken as done, with
## nothing lost.

static var ENABLED := true

const CHAPTER := "Cocaine Cowboys"
const GRACE_S := 900.0
const CASH_KEPT := 0.25

var sess
var rng: PyRandom
var done := false
var at := -1.0
var summary := {}  ## what it cost: {stashes_lost, stashes_kept, crew_left, crew_stayed, trucks_lost, cash_lost, cash_kept}
var _since := -1.0  ## when the chapter was first seen open
var _incident := false


func _init(sess_, rng_: PyRandom) -> void:
	sess = sess_
	rng = rng_
	sess.bus.subscribe("truck_hijacked", func(_e): _incident = true)
	sess.bus.subscribe("hijacked", func(_e): _incident = true)


static func chapter_index() -> int:
	return Story.index_of(CHAPTER)


## Rafa is alive and the chapter he dies in is open: the desk is still his.
func pending() -> bool:
	return ENABLED and not done and _story() != null and _story().index == chapter_index()


func _story():
	var st = sess.story
	if st == null or (st.employment != null and st.employment.active()):
		return null
	return st


func update(_dt: float) -> void:
	if not ENABLED or done:
		return
	var st = _story()
	if st == null or st.index < chapter_index():
		return
	if st.index > chapter_index():
		if _since >= 0.0:
			fire()  # the chapter closed before the streets moved: he does not outlive it
		else:
			done = true  # never seen open here (an older save, or a chapter picked from the menu): taken as done, nothing lost
		return
	if _since < 0.0:
		_since = sess.time
	if _incident or _rival_fight() or sess.time - _since >= GRACE_S:
		fire()


func _rival_fight() -> bool:
	if sess.ground == null:
		return false
	for f in sess.ground.fights:
		if f.a.faction == "rival" or f.b.faction == "rival":
			return true
	return false


## It happens now.
func fire() -> void:
	if done:
		return
	done = true
	at = sess.time
	var lost_names := []
	var kept := 0
	var trucks_lost := _lose_trucks()
	var cash_before := 0.0
	var lg = sess.logistics
	if lg != null:
		for site in lg.cash:
			cash_before += float(lg.cash[site])
	if sess.stash_net != null:
		var live: Array = sess.stash_net.live()
		rng.shuffle(live)  # ties between equally known houses fall by the draw
		live.sort_custom(func(a, b): return StashNet.suspicion(a) > StashNet.suspicion(b))
		var n_lost: int = live.size() / 2
		for i in live.size():
			var st: Dictionary = live[i]
			if i < n_lost:
				_lose_stash(st)
				lost_names.append(str(st.name))
			else:
				kept += 1
	var cash_after := 0.0
	if lg != null:
		var surviving := 0.0
		for site in lg.cash:
			surviving += float(lg.cash[site])
		var target := cash_before * CASH_KEPT
		if surviving > target and surviving > 0.0:
			var f := target / surviving
			for site in lg.cash:
				var cut: float = float(lg.cash[site]) * (1.0 - f)
				if cut >= 0.01:
					lg.book_cash(Logistics.STREET, "outside:rival", cut, "loss")
					lg.cash[site] = float(lg.cash[site]) - cut
					lg.lost.cash += int(cut)
		for site in lg.cash:
			cash_after += float(lg.cash[site])
		lg.sync()
	var crew := _lose_crew()
	if sess.trade != null:
		sess.trade.trust.own["rival"] = 0.0
	summary = {"stashes_lost": lost_names, "stashes_kept": kept, "crew_left": crew[0], "crew_stayed": crew[1], "trucks_lost": trucks_lost,
		"cash_lost": int(round(cash_before - cash_after)), "cash_kept": int(round(cash_after))}
	var text := headline()
	sess.say("NEWS - " + text)
	sess.bus.emit("takeover", sess.time, text, ["runner"], summary.duplicate(true))


## What the player hears.
func headline() -> String:
	var parts := []
	if not (summary.get("stashes_lost", []) as Array).is_empty():
		parts.append("%s gone to them" % _and(summary.stashes_lost))
	if int(summary.get("crew_left", 0)) > 0:
		parts.append("%d of the crew walked" % int(summary.crew_left))
	if int(summary.get("trucks_lost", 0)) > 0:
		parts.append("%d truck%s taken on the road" % [int(summary.trucks_lost), "" if int(summary.trucks_lost) == 1 else "s"])
	if int(summary.get("cash_lost", 0)) > 0:
		parts.append("$%s of the street money with them" % Py.money(int(summary.cash_lost)))
	return "Los Cuervos stopped Rafa on the road. They say he is dead. %sHis desk is yours." % (
		(", ".join(parts).capitalize() + ". ") if not parts.is_empty() else "")


static func _and(names: Array) -> String:
	if names.size() <= 1:
		return "" if names.is_empty() else str(names[0])
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + str(names[-1])


func _lose_stash(st: Dictionary) -> void:
	var id := str(st.id)
	var lg = sess.logistics
	if lg != null:
		lg.taken(id, "rival")
	if sess.arsenals.has("org") and sess.arsenals.has("rival") and str(sess.arsenals["org"].cache) == id:
		sess.arsenals["org"].seize_into(sess.arsenals["rival"])  # the armoury was kept there: theirs now
		sess.arsenals["rival"].seized_total = 0  # (a count the task force keeps, not a gang)
		sess.arsenals["org"].cache = ""
	st.burned = true
	if sess.payroll != null:
		for w in sess.payroll.of("org", "", "assigned"):
			if str(w.assigned) == "stash-" + id:
				w.status = "free"
				w.assigned = ""


## Every truck on the road is lost with its load; returns how many.
func _lose_trucks() -> int:
	if sess.stash_net == null:
		return 0
	var n := 0
	for t in sess.stash_net.trucks.duplicate():
		sess.stash_net.trucks.erase(t)
		n += 1
		if sess.logistics != null and sess.logistics.owns(t):
			sess.logistics.arrived(t, "hijacked", "the takeover")
		elif not t.weapons.is_empty() and sess.arsenals.has("rival"):
			sess.arsenals["rival"].add_all(t.weapons)
	return n


## Half the crew walks: [left, stayed]. Men in a squad stay with it.
func _lose_crew() -> Array:
	var p = sess.payroll
	if p == null:
		return [0, 0]
	var in_squads := {}
	for sid in p.squads:
		for id in p.squads[sid]:
			in_squads[str(id)] = true
	var crew: Array = p.workers.filter(func(w): return w.outfit == "org" and w.status in ["free", "assigned"] and not in_squads.has(str(w.id)))
	rng.shuffle(crew)
	var n_left: int = crew.size() / 2
	for i in n_left:
		var w: Dictionary = crew[i]
		w.status = "gone"
		p.workers.erase(w)
	return [n_left, crew.size() - n_left]


func view() -> Dictionary:
	return {"done": done, "pending": pending(), "at": at, "summary": summary.duplicate(true)}


func capture() -> Dictionary:
	return {"done": done, "at": at, "since": _since, "summary": summary.duplicate(true)}


## `d` is the saved block, or {} for a save from before the takeover existed (update takes one already past the chapter as done).
func restore(d: Dictionary) -> void:
	if d.is_empty():
		return
	done = bool(d.get("done", false))
	at = float(d.get("at", -1.0))
	_since = float(d.get("since", -1.0))
	summary = (d.get("summary", {}) as Dictionary).duplicate(true) if d.get("summary") is Dictionary else {}
	for k in ["stashes_kept", "crew_left", "crew_stayed", "trucks_lost", "cash_lost", "cash_kept"]:
		if summary.has(k):
			summary[k] = int(summary[k])
