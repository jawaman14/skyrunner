extends TestCase
## Covers PickupOrder lifecycle transitions, guards and failure costs.


func test_happy_path_ordered_to_collected() -> void:
	var order := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	check_eq(order.state, PickupOrder.ORDERED)
	order.advance(5.0, false)
	check_eq(order.state, PickupOrder.WINDOW)
	order.advance(6.0, true)
	check_eq(order.state, PickupOrder.AT_PLACE)
	check(order.collect())


func test_late_when_window_closes_without_arrival() -> void:
	var order := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	order.advance(5.0, false)
	check_eq(order.state, PickupOrder.WINDOW)
	order.advance(35.1, false)
	check_eq(order.state, PickupOrder.LATE)
	check_eq(order.failure_cost(), "trust")


func test_terminal_state_ignores_advance() -> void:
	var order := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	order.advance(5.0, false)
	order.advance(6.0, true)
	check_eq(order.state, PickupOrder.AT_PLACE)
	check(order.collect())
	check_eq(order.state, PickupOrder.COLLECTED)
	order.advance(100.0, false)
	check_eq(order.state, PickupOrder.COLLECTED)


func test_collect_only_works_at_place() -> void:
	var order := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	check(not order.collect())
	check_eq(order.state, PickupOrder.ORDERED)
	order.advance(5.0, false)
	check(not order.collect())
	check_eq(order.state, PickupOrder.WINDOW)
	order.advance(6.0, true)
	check_eq(order.state, PickupOrder.AT_PLACE)
	check(order.collect())


func test_cancel_refused_at_place_works_when_ordered() -> void:
	var at_place := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	at_place.advance(5.0, false)
	at_place.advance(6.0, true)
	check_eq(at_place.state, PickupOrder.AT_PLACE)
	check(not at_place.cancel())
	check_eq(at_place.state, PickupOrder.AT_PLACE)
	var ordered := PickupOrder.make(10, "dock", 0.0, 5.0, 30.0)
	check(ordered.cancel())
	check_eq(ordered.state, PickupOrder.CANCELLED)


func test_failure_cost_for_each_state() -> void:
	var late := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	late.advance(5.0, false)
	late.advance(35.1, false)
	check_eq(late.failure_cost(), "trust")
	var intercepted := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	intercepted.intercept()
	check_eq(intercepted.failure_cost(), "lot")
	var cancelled := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	cancelled.cancel()
	check_eq(cancelled.failure_cost(), "cash")
	var collected := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	collected.advance(5.0, false)
	collected.advance(6.0, true)
	collected.collect()
	check_eq(collected.failure_cost(), "none")


func test_leaving_the_place_goes_back_to_the_window() -> void:
	var order := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	order.advance(5.0, false)
	order.advance(6.0, true)
	check_eq(order.state, PickupOrder.AT_PLACE)
	order.advance(7.0, false)
	check_eq(order.state, PickupOrder.WINDOW)
	check(not order.collect(), "nothing to collect away from the place")
	order.advance(8.0, true)
	check(order.collect(), "back at the place it can be collected")
	var late := PickupOrder.make(10, "beach", 0.0, 5.0, 30.0)
	late.advance(5.0, false)
	late.advance(6.0, true)
	late.advance(35.1, false)
	check_eq(late.state, PickupOrder.LATE, "the window closing still wins")
