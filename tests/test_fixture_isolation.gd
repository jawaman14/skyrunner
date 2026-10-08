extends TestCase

func _all_read_only(value: Variant) -> bool:
	if value is Dictionary:
		if not value.is_read_only(): return false
		for child in value.values():
			if not _all_read_only(child): return false
	elif value is Array:
		if not value.is_read_only(): return false
		for child in value:
			if not _all_read_only(child): return false
	return true

func test_cached_parity_oracle_is_recursively_read_only() -> void:
	var oracle := T.golden()
	check(not oracle.is_empty())
	check(_all_read_only(oracle), "nested arrays and dictionaries cannot leak mutations between tests")
	check_eq(T.golden(), oracle, "cached reads preserve the exact oracle")
