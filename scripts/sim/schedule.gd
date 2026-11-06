class_name Schedule
extends RefCounted
## The scheduler (F-6, docs/EMPIRE_SIMULATION_SPEC.md section 5): things that happen at a time, not every tick. A min-heap on
## (t, serial), so two entries due at the same moment always run in the order they were set, every run, every machine.
## No clock of its own: `due(now)` hands back what has come due on the session's one clock. Saved.

static var ENABLED := true

var heap: Array = []  ## [t, serial, kind, payload]
var _serial := 0


## Set `kind` (with `payload`) to come due at `t`. Returns its serial, for cancel().
func at(t: float, kind: String, payload := {}) -> int:
	_serial += 1
	heap.append([t, _serial, kind, payload])
	_up(heap.size() - 1)
	return _serial


func cancel(serial: int) -> bool:
	for i in heap.size():
		if int(heap[i][1]) == serial:
			heap[i] = heap.back()
			heap.pop_back()
			if i < heap.size():
				_down(i)
				_up(i)
			return true
	return false


## Everything due by `now`, earliest first: [[t, serial, kind, payload], ...], removed from the heap.
func due(now: float) -> Array:
	var out := []
	while not heap.is_empty() and float(heap[0][0]) <= now:
		out.append(_pop())
	return out


func next_t() -> float:
	return float(heap[0][0]) if not heap.is_empty() else INF


func has_kind(kind: String) -> bool:
	return heap.any(func(e): return str(e[2]) == kind)


func capture() -> Dictionary:
	return {"heap": heap.duplicate(true), "serial": _serial}


func restore(d: Dictionary) -> void:
	heap = []
	for e in d.get("heap", []):
		heap.append([float(e[0]), int(e[1]), str(e[2]), (e[3] as Dictionary) if e[3] is Dictionary else {}])
	_serial = int(d.get("serial", 0))
	for i in range(heap.size() / 2 - 1, -1, -1):  # whatever order the save kept, the heap holds again
		_down(i)


static func _less(a: Array, b: Array) -> bool:
	return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1]))


func _pop() -> Array:
	var top: Array = heap[0]
	heap[0] = heap.back()
	heap.pop_back()
	if not heap.is_empty():
		_down(0)
	return top


func _up(i: int) -> void:
	while i > 0:
		var p := (i - 1) / 2
		if not _less(heap[i], heap[p]):
			return
		var tmp: Array = heap[i]
		heap[i] = heap[p]
		heap[p] = tmp
		i = p


func _down(i: int) -> void:
	var n := heap.size()
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var m := i
		if l < n and _less(heap[l], heap[m]):
			m = l
		if r < n and _less(heap[r], heap[m]):
			m = r
		if m == i:
			return
		var tmp: Array = heap[i]
		heap[i] = heap[m]
		heap[m] = tmp
		i = m
