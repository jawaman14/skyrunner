class_name PhoneCalls
extends RefCounted
## Deterministic incoming-call queue shared by cockpit and on-foot phone surfaces.
## The simulation owns state; UI consumes snapshots and routes answer/decline actions.

const RING_SECONDS := 20.0

var _next_id := 1
var _calls: Array[Dictionary] = []

func enqueue(action: String, from: String, now: float, duration := RING_SECONDS, source := "") -> Dictionary:
	for call in _calls:
		if (source != "" and call.get("source", "") == source) or (source == "" and call.state == "pending" and call.action == action):
			return call.duplicate(true)
	var call := {"id": _next_id, "action": action, "from": from, "created": now,
		"expires": now + maxf(1.0, duration), "state": "pending", "source": source}
	_next_id += 1
	_calls.append(call)
	return call.duplicate(true)

func tick(now: float) -> void:
	for call in _calls:
		if call.state == "pending" and now >= float(call.expires):
			call.state = "missed"

func pending() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for call in _calls:
		if call.state == "pending":
			out.append(call.duplicate(true))
	return out


func history() -> Array[Dictionary]:
	return _calls.duplicate(true)

func answer(id: int) -> Dictionary:
	return _set_state(id, "answered")

func decline(id: int) -> Dictionary:
	return _set_state(id, "declined")

func _set_state(id: int, state: String) -> Dictionary:
	for call in _calls:
		if int(call.id) == id:
			if call.state != "pending":
				return {"ok": false, "reason": "call-%s" % call.state, "call": call.duplicate(true)}
			call.state = state
			return {"ok": true, "call": call.duplicate(true)}
	return {"ok": false, "reason": "unknown-call"}

func capture() -> Dictionary:
	return {"next_id": _next_id, "calls": _calls.duplicate(true)}

func restore(data: Dictionary) -> void:
	_next_id = maxi(1, int(data.get("next_id", 1)))
	_calls.clear()
	for raw in data.get("calls", []):
		if raw is Dictionary and raw.has("id") and raw.has("action") and raw.has("state"):
			var call: Dictionary = raw.duplicate(true)
			call.id = int(call.id)
			_calls.append(call)
			_next_id = maxi(_next_id, int(call.id) + 1)
