class_name StockLedger
extends RefCounted
## Valued rows for a set of lots, sorted by worth, so a manifest can show what to sell first.


## One row per lot with its age, valuation and source, highest value first (stable for ties).
static func rows(lots: Array, now: float, prices: Dictionary, half_lives: Dictionary) -> Array:
	var out: Array = []
	var i := 0
	for lot: StockLot in lots:
		var age_s: float = lot.age(now)
		var price_per_lb: float = float(prices.get(lot.good, 0.0))
		var half_life_s: float = float(half_lives.get(lot.good, 0.0))
		out.append({
			"good": lot.good,
			"units": lot.units,
			"lb": lot.lb,
			"grade": lot.grade,
			"age_s": age_s,
			"hot": lot.hot,
			"origin": lot.origin,
			"value": StockValue.value(price_per_lb, lot.lb, lot.grade, age_s, half_life_s),
			"_i": i,
		})
		i += 1
	# sort_custom is not stable, so ties fall back to the input position
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["value"]) == float(b["value"]):
			return int(a["_i"]) < int(b["_i"])
		return float(a["value"]) > float(b["value"]))
	for row: Dictionary in out:
		row.erase("_i")
	return out


## Aggregate weight, worth and flagged weight for a manifest header.
static func totals(rows: Array) -> Dictionary:
	var lb: float = 0.0
	var value: float = 0.0
	var hot_lb: float = 0.0
	for row: Dictionary in rows:
		lb += float(row["lb"])
		value += float(row["value"])
		if bool(row["hot"]):
			hot_lb += float(row["lb"])
	return {"lb": lb, "value": value, "hot_lb": hot_lb}
