extends TestCase
## Affinity roll thresholds and payoffs.
## Every static helper is exercised with its boundary values.


func test_roll_thresholds() -> void:
	check_eq(Affinity.roll(0.0), Affinity.HATE, "0.0 -> HATE")
	check_eq(Affinity.roll(0.1), Affinity.FRIEND, "0.1 -> FRIEND")
	check_eq(Affinity.roll(0.3), Affinity.LOVE, "0.3 -> LOVE")
	check_eq(Affinity.roll(0.35), Affinity.NONE, "0.35 -> NONE")
	check_eq(Affinity.roll(0.99), Affinity.NONE, "0.99 -> NONE")


func test_pay_mult() -> void:
	check(absf(Affinity.pay_mult(Affinity.HATE) - 0.90) < 0.0001, "hate pay")
	check(absf(Affinity.pay_mult(Affinity.FRIEND) - 1.05) < 0.0001, "friend pay")
	check(absf(Affinity.pay_mult(Affinity.LOVE) - 1.10) < 0.0001, "love pay")
	check(absf(Affinity.pay_mult(Affinity.NONE) - 1.0) < 0.0001, "none pay")
	check(absf(Affinity.pay_mult("bogus") - 1.0) < 0.0001, "unknown kind pay")


func test_only_hate_refuses() -> void:
	check(Affinity.refuses_together(Affinity.HATE), "hate refuses")
	check(not Affinity.refuses_together(Affinity.FRIEND), "friend works")
	check(not Affinity.refuses_together(Affinity.LOVE), "love works")
	check(not Affinity.refuses_together(Affinity.NONE), "none works")
	check(not Affinity.refuses_together("bogus"), "unknown kind works")


func test_partner_loyalty_drop() -> void:
	check(absf(Affinity.partner_loyalty_drop(Affinity.HATE) - 0.0) < 0.0001, "hate drop")
	check(absf(Affinity.partner_loyalty_drop(Affinity.FRIEND) - 5.0) < 0.0001, "friend drop")
	check(absf(Affinity.partner_loyalty_drop(Affinity.LOVE) - 15.0) < 0.0001, "love drop")
	check(absf(Affinity.partner_loyalty_drop(Affinity.NONE) - 0.0) < 0.0001, "none drop")
	check(absf(Affinity.partner_loyalty_drop("bogus") - 0.0) < 0.0001, "unknown kind drop")


func test_labels() -> void:
	check(Affinity.label(Affinity.HATE, "Rico").contains("Rico"), "hate names other")
	check(Affinity.label(Affinity.FRIEND, "Rico").contains("Rico"), "friend names other")
	check(Affinity.label(Affinity.LOVE, "Rico").contains("Rico"), "love names other")
	check_eq(Affinity.label(Affinity.NONE, "Rico"), "", "none is empty")
	check_eq(Affinity.label("bogus", "Rico"), "", "unknown kind is empty")
