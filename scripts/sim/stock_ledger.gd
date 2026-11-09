class_name StockLedger
extends RefCounted
## Valued rows for a set of lots, sorted by worth, so a manifest can show what to sell first.


## One row per lot with its age, valuation and source, highest value first (stable for ties). `extra[i]`, when given, is merged
## into lot i's row (the session's place, lot id and quote).
static func rows(lots: Array, now: float, prices: Dictionary, half_lives: Dictionary, extra := []) -> Array:
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
		if i < extra.size():
			out[-1].merge(extra[i])
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


# ------------------------------------------------------------------ the session's stock (DESIGN 51.4, slice 4)
## Where a lot of ours sits, as the boss reads it: a stash by name, the aircraft, a truck on the road. "" for a place that isn't
## ours (outside:*, a business's shelf).
static func place_of(sess, at: String) -> String:
	if at.begins_with("stash:"):
		return sess.logistics.name_of(at.substr(6)) if sess.logistics != null else at.substr(6)
	if at.begins_with("aircraft:"):
		return "the aircraft"
	if at.begins_with(Logistics.ROAD):
		return "a truck on the road"
	return ""


## The best open quote for `lb` of `good` now: {price a pound, buyer, market}, from the bulk buyers whose door is open and have
## room, and the street at the markets where our corners are. Price 0 and buyer "" when nobody is buying.
static func best_quote(sess, good: String) -> Dictionary:
	var best := {"price": 0.0, "buyer": "", "market": ""}
	if sess.trade == null:
		return best
	for b in Trade.BUYERS:
		var q: Dictionary = sess.trade.quote(b, good)
		if str(q.why) == "" and float(q.room) >= 1.0 and float(q.price) > float(best.price):
			best = {"price": float(q.price), "buyer": str(Trade.BUYERS[b].name), "market": str(Trade.BUYERS[b].market)}
	for m in sess.trade._corners("org"):
		var p: float = sess.trade.street_price(good, str(m))
		if p > float(best.price):
			best = {"price": p, "buyer": "our corners", "market": str(m)}
	return best


## Every lot of product we hold, valued at its best open quote, highest first: {rows, totals}. Each row adds `id`, `place`,
## `heat` and the quote's `buyer` and `market` to rows()'s fields. The goods don't spoil (no half-life yet); age is shown.
static func of_session(sess) -> Dictionary:
	if sess.inventory == null:
		return {"rows": [], "totals": totals([])}
	var lots: Array = []
	var meta: Array = []
	var prices := {}
	var quotes := {}
	var ids: Array = sess.inventory.lots.keys()
	ids.sort()
	for id in ids:
		var l: Dictionary = sess.inventory.lots[id]
		var place := place_of(sess, str(l.at))
		if place == "" or not str(l.good) in Trade.GOODS or float(l.lb) < 0.01:
			continue
		if not quotes.has(l.good):
			quotes[l.good] = best_quote(sess, str(l.good))
			prices[l.good] = float(quotes[l.good].price)
		lots.append(StockLot.make(str(l.good), float(l.lb), float(l.quality), float(l.born), str(l.origin), float(l.heat) > 0.0))
		var q: Dictionary = quotes[l.good]
		meta.append({"id": int(id), "place": place, "heat": float(l.heat), "buyer": q.buyer, "market": q.market})
	var out := rows(lots, float(sess.time), prices, {}, meta)
	return {"rows": out, "totals": totals(out)}
