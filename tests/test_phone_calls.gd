extends TestCase
const PhoneCalls = preload("res://scripts/sim/phone_calls.gd")

func test_pending_call_is_deduplicated_and_can_be_answered() -> void:
	var q := PhoneCalls.new()
	var first := q.enqueue("buyers", "Benny Ruiz", 10.0)
	var duplicate := q.enqueue("buyers", "Benny Ruiz", 11.0)
	check_eq(duplicate.id, first.id)
	check_eq(q.pending().size(), 1)
	var result := q.answer(int(first.id))
	check(result.ok)
	check_eq(result.call.state, "answered")
	check_eq(q.pending().size(), 0)

func test_calls_expire_as_missed_and_cannot_be_replayed() -> void:
	var q := PhoneCalls.new()
	var call := q.enqueue("lawyer", "Your lawyer", 20.0, 5.0)
	q.tick(25.0)
	var result := q.answer(int(call.id))
	check(not result.ok)
	check_eq(result.reason, "call-missed")

func test_save_load_preserves_queue_and_ids() -> void:
	var q := PhoneCalls.new()
	q.enqueue("crew", "Manny Ortega", 1.0)
	var snap := q.capture()
	var restored: RefCounted = PhoneCalls.new()
	restored.restore(snap)
	check_eq(restored.pending().size(), 1)
	var next: Dictionary = restored.enqueue("dealer", "Dealership", 2.0)
	check(int(next.id) > 1)
