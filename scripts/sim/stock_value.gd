class_name StockValue
extends RefCounted
## What a lot of stock is worth now: price by weight, scaled by grade, and halved every half-life it has aged.


## The share of value left after `age_s` seconds; 1.0 for goods that do not spoil (`half_life_s` <= 0).
static func aged(age_s: float, half_life_s: float) -> float:
	if half_life_s <= 0.0:
		return 1.0
	return pow(0.5, maxf(age_s, 0.0) / half_life_s)


## Price per lb times weight times (0.5 + grade), so a poor lot still sells for something; grade is clamped to 0..1.
static func value(base_price_per_lb: float, lb: float, grade: float, age_s: float, half_life_s: float) -> float:
	return base_price_per_lb * maxf(lb, 0.0) * (0.5 + clampf(grade, 0.0, 1.0)) * aged(age_s, half_life_s)
