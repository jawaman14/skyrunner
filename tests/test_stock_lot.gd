extends TestCase

## Verifies StockLot round trips, missing-key defaults and clamped age.
## Also checks to_dict serializes only String keys with scalar values.


func test_round_trip_keeps_every_field() -> void:
	var lot := StockLot.make("Iron Ore", 120.5, 0.8, 100.0, "Costa Brava", true)
	var back := StockLot.from_dict(lot.to_dict())
	check_eq(back.good, "Iron Ore", "good survives round trip")
	check(absf(back.lb - 120.5) < 0.0001, "lb survives round trip")
	check(absf(back.grade - 0.8) < 0.0001, "grade survives round trip")
	check(absf(back.born_at - 100.0) < 0.0001, "born_at survives round trip")
	check_eq(back.origin, "Costa Brava", "origin survives round trip")
	check(back.hot, "hot survives round trip")


func test_missing_keys_use_defaults() -> void:
	var lot := StockLot.from_dict({})
	check_eq(lot.good, "", "good defaults to empty")
	check(absf(lot.lb - 0.0) < 0.0001, "lb defaults to zero")
	check(absf(lot.grade - 0.5) < 0.0001, "grade defaults to 0.5")
	check(absf(lot.born_at - 0.0) < 0.0001, "born_at defaults to zero")
	check_eq(lot.origin, "", "origin defaults to empty")
	check(not lot.hot, "hot defaults to false")


func test_age_is_never_negative() -> void:
	var lot := StockLot.make("Salt", 10.0, 0.5, 500.0, "", false)
	check(absf(lot.age(500.0) - 0.0) < 0.0001, "age is zero at birth")
	check(absf(lot.age(510.0) - 10.0) < 0.0001, "age grows with now")
	check(absf(lot.age(400.0) - 0.0) < 0.0001, "age clamps to zero before birth")


func test_to_dict_holds_only_string_keys_and_scalars() -> void:
	var d := StockLot.make("Grain", 42.0, 0.6, 7.0, "Haven", false).to_dict()
	check_eq(d.size(), 7, "dict holds the seven fields")
	for key in d.keys():
		check(key is String, "every key is a String")
		var value_type := typeof(d[key])
		check(
			value_type == TYPE_STRING or value_type == TYPE_FLOAT or value_type == TYPE_BOOL,
			"every value is String, float or bool"
		)


func test_units_default_to_the_weight_and_can_differ() -> void:
	var weighed := StockLot.make("grass", 40.0, 0.5, 0.0, "port", false)
	check_eq(weighed.units, 40.0, "pounds are both")
	var sheets := StockLot.make("acid", 2.0, 0.7, 0.0, "collective", false, 500.0)
	check_eq(StockLot.from_dict(sheets.to_dict()).units, 500.0, "sheets survive a round trip")
	check_eq(StockLot.from_dict({"lb": 12.0}).units, 12.0, "an old dictionary takes its weight")
