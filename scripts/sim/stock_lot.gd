class_name StockLot
extends RefCounted

## One stowed cargo lot whose grade, weight and age drive sale and decay math.

var good: String = ""
var lb: float = 0.0  ## transport weight
var units: float = 0.0  ## what it is sold in: pounds, sheets, weapons or crates (defaults to the weight)
var grade: float = 0.5
var born_at: float = 0.0
var origin: String = ""
var hot: bool = false


static func make(good: String, lb: float, grade: float, born_at: float, origin: String, hot: bool, units := -1.0) -> StockLot:
	var lot := StockLot.new()
	lot.good = good
	lot.lb = lb
	lot.units = lb if units < 0.0 else units
	lot.grade = grade
	lot.born_at = born_at
	lot.origin = origin
	lot.hot = hot
	return lot


func to_dict() -> Dictionary:
	return {
		"good": good,
		"lb": lb,
		"units": units,
		"grade": grade,
		"born_at": born_at,
		"origin": origin,
		"hot": hot,
	}


static func from_dict(d: Dictionary) -> StockLot:
	var lot := StockLot.new()
	lot.good = str(d.get("good", ""))
	lot.lb = float(d.get("lb", 0.0))
	lot.units = float(d.get("units", lot.lb))
	lot.grade = float(d.get("grade", 0.5))
	lot.born_at = float(d.get("born_at", 0.0))
	lot.origin = str(d.get("origin", ""))
	lot.hot = bool(d.get("hot", false))
	return lot


func age(now: float) -> float:
	return maxf(0.0, now - born_at)
