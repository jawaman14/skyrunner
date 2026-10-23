class_name PickupOrder
extends RefCounted
## Pickup order lifecycle: ordered -> window -> at_place -> collected, with failure exits.

const ORDERED := "ordered"
const WINDOW := "window"
const AT_PLACE := "at_place"
const COLLECTED := "collected"
const LATE := "late"
const INTERCEPTED := "intercepted"
const CANCELLED := "cancelled"

var state: String = ORDERED
var paid: int
var place: String
var opens_at: float
var closes_at: float


static func make(p_order_paid: int, p_place: String, now: float, opens_in_s: float, window_s: float) -> PickupOrder:
	var order := PickupOrder.new()
	order.paid = p_order_paid
	order.place = p_place
	order.opens_at = now + opens_in_s
	order.closes_at = order.opens_at + window_s
	return order


func advance(now: float, at_place: bool) -> void:
	match state:
		ORDERED:
			if now >= opens_at:
				state = WINDOW
		WINDOW:
			if now > closes_at:
				state = LATE
			elif at_place:
				state = AT_PLACE
		AT_PLACE:
			if now > closes_at:
				state = LATE
			elif not at_place:
				state = WINDOW  # walked off: nothing to collect until they are back (DESIGN 51.9)


func collect() -> bool:
	if state != AT_PLACE:
		return false
	state = COLLECTED
	return true


func intercept() -> void:
	if state == ORDERED or state == WINDOW or state == AT_PLACE:
		state = INTERCEPTED


func cancel() -> bool:
	if state != ORDERED and state != WINDOW:
		return false
	state = CANCELLED
	return true


func failure_cost() -> String:
	match state:
		LATE:
			return "trust"
		INTERCEPTED:
			return "lot"
		CANCELLED:
			return "cash"
		_:
			return "none"
