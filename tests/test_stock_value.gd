extends TestCase
## StockValue: pure stock valuation helper (price * lb * grade factor * age decay).
## Static functions only; no state, no scene dependencies.


func test_half_life_halves_value() -> void:
	var fresh: float = StockValue.value(100.0, 10.0, 1.0, 0.0, 600.0)
	var aged_one: float = StockValue.value(100.0, 10.0, 1.0, 600.0, 600.0)
	check(absf(fresh - 1500.0) < 0.0001, "fresh value should be 1500.0")
	check(absf(aged_one - 750.0) < 0.0001, "one half-life should halve the value")


func test_grade_zero_is_half_price_scaled() -> void:
	var g1: float = StockValue.value(100.0, 10.0, 1.0, 0.0, 600.0)
	var g0: float = StockValue.value(100.0, 10.0, 0.0, 0.0, 600.0)
	check(absf(g0 - g1 * (0.5 / 1.5)) < 0.0001, "grade 0 should be (0.5/1.5) of grade 1")


func test_grade_is_clamped() -> void:
	var high: float = StockValue.value(100.0, 10.0, 2.0, 0.0, 600.0)
	var one: float = StockValue.value(100.0, 10.0, 1.0, 0.0, 600.0)
	check(absf(high - one) < 0.0001, "grade 2.0 must equal grade 1.0")
	var neg: float = StockValue.value(100.0, 10.0, -1.0, 0.0, 600.0)
	var zero: float = StockValue.value(100.0, 10.0, 0.0, 0.0, 600.0)
	check(absf(neg - zero) < 0.0001, "grade -1.0 must equal grade 0.0")


func test_negative_lb_gives_zero() -> void:
	var v: float = StockValue.value(100.0, -5.0, 1.0, 0.0, 600.0)
	check(absf(v - 0.0) < 0.0001, "negative lb must yield 0.0")


func test_zero_half_life_means_no_ageing() -> void:
	var fresh: float = StockValue.value(100.0, 10.0, 1.0, 0.0, 0.0)
	var old: float = StockValue.value(100.0, 10.0, 1.0, 99999.0, 0.0)
	check(absf(fresh - old) < 0.0001, "half_life <= 0 must skip ageing")


func test_aged_returns_fraction() -> void:
	var at_start: float = StockValue.aged(0.0, 600.0)
	check(absf(at_start - 1.0) < 0.0001, "aged(0) must be 1.0")
	var two_halves: float = StockValue.aged(1200.0, 600.0)
	check(absf(two_halves - 0.25) < 0.0001, "two half-lives must be 0.25")
	var no_decay: float = StockValue.aged(5000.0, 0.0)
	check(absf(no_decay - 1.0) < 0.0001, "aged with half_life <= 0 must be 1.0")
