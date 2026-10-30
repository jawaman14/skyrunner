class_name GoalMarks
extends RefCounted
## Where the next chapter goal can be done (owner, 30 Oct: "markers so you know what could help you get to the next chapter").
## A read-only look at the story's first required goal not yet met and the session's state: no random draw, nothing saved.
## The minimap draws these as gold diamonds and the pilot app stands a gold beacon over each.

const MAX_MARKS := 6


## [{x, y, label}]: the places that move the story's next required goal on. [] with no story, or for a goal with no place (a phone call).
static func of(s) -> Array:
	if s.story == null:
		return []
	var st = s.story
	if st.employment != null and st.employment.active():
		return _employer(s)
	for o in st.chapter.objectives:
		if o.optional or st.outcomes.has(o.key) or float(st.progress.get(o.key, 0.0)) >= o.target:
			continue
		var marks: Array = _for_goal(s, str(o.key))
		return marks.slice(0, MAX_MARKS)
	return []


static func _employer(s) -> Array:
	if not s.active_jobs.is_empty():
		return s.active_jobs.map(func(j): return _job_mark(j, "Deliver here"))
	if s.location != null and World.AIRFIELD_BY_CODE.has(s.location):
		return [_at_field(s.location, "Employer's job board [J]")]
	return []


static func _for_goal(s, key: String) -> Array:
	match key:
		"weed_lb", "grass_lb":
			var out := []
			for j in s.active_jobs:  # a grass load aboard: where it goes
				if j.own_good == "marijuana" or Economy.good_of(j) == "marijuana":
					out.append(_job_mark(j, "Land the grass here"))
			if not out.is_empty():
				return out
			for af in s.world.airfields:  # else: the bush strips with grass work on their boards
				if af.kind == "bush" and s.boards.get(af.code, []).any(func(j): return j.own_good == "marijuana" or Economy.good_of(j) == "marijuana"):
					out.append(_at_field(af.code, "Grass job here [J]"))
			if out.is_empty():
				for af in s.world.airfields:
					if af.kind == "bush":
						out.append(_at_field(af.code, "Grass work: bush strip"))
			return out
		"trade_earned":
			return _stashes(s, func(sh): return true, func(sh): return "Dealers sell from here")
		"cash_home":
			if s.logistics == null:
				return []
			if int(s.logistics.aboard) > 0:  # cash in the bags aboard: where it is unloaded home, before more pickups
				var hq: String = str(s.logistics.hq_strip())
				if World.AIRFIELD_BY_CODE.has(hq):
					return [_at_field(hq, "unload the $%s aboard here [U]" % Py.money(int(s.logistics.aboard)))]
			return _stashes(s, func(sh): return float(s.logistics.cash.get(sh.id, 0.0)) >= 100.0,
				func(sh): return "$%s to bring home" % Py.money(int(s.logistics.cash.get(sh.id, 0.0))))
	return []


static func _stashes(s, keep: Callable, label: Callable) -> Array:
	if s.stash_net == null:
		return []
	var out := []
	for sh in s.stash_net.live():
		if keep.call(sh):
			out.append({"x": float(sh.x), "y": float(sh.y), "label": str(label.call(sh))})
	return out


## A job's own place: the sea rendezvous for an airdrop (its "dest" is SEA, not a strip), else its strip.
static func _job_mark(j, label: String) -> Dictionary:
	if j.is_airdrop():
		return {"x": float(j.drop_point[0]), "y": float(j.drop_point[1]), "label": "Drop the bales here"}
	return _at_field(j.dest, label)


static func _at_field(code: String, label: String) -> Dictionary:
	var af := World.airfield(code)
	return {"x": af.x, "y": af.y, "label": "%s: %s" % [af.name, label]}
