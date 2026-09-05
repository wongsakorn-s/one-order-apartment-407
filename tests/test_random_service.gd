class_name TestRandomService
extends RefCounted

## Automated unit tests for RandomService deterministic behavior.

const RandomServiceClass = preload("res://scripts/simulation/random_service.gd")

static func run_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_test_deterministic_same_seed())
	results.append(_test_different_seeds_diverge())
	results.append(_test_range_bounds())
	results.append(_test_pick_and_shuffle())
	results.append(_test_reset())
	return results

static func _test_deterministic_same_seed() -> Dictionary:
	var seed_val: int = 42891
	var rng1 = RandomServiceClass.new(seed_val)
	var rng2 = RandomServiceClass.new(seed_val)

	for i in range(100):
		var f1: float = rng1.rand_float()
		var f2: float = rng2.rand_float()
		if not is_equal_approx(f1, f2):
			return {"name": "test_deterministic_same_seed", "passed": false, "error": "Floats differed at index %d: %f vs %f" % [i, f1, f2]}

		var i1: int = rng1.rand_range_int(1, 1000)
		var i2: int = rng2.rand_range_int(1, 1000)
		if i1 != i2:
			return {"name": "test_deterministic_same_seed", "passed": false, "error": "Ints differed at index %d: %d vs %d" % [i, i1, i2]}

	return {"name": "test_deterministic_same_seed", "passed": true}

static func _test_different_seeds_diverge() -> Dictionary:
	var rng1 = RandomServiceClass.new(12345)
	var rng2 = RandomServiceClass.new(67890)

	var all_identical: bool = true
	for i in range(20):
		if not is_equal_approx(rng1.rand_float(), rng2.rand_float()):
			all_identical = false
			break

	if all_identical:
		return {"name": "test_different_seeds_diverge", "passed": false, "error": "Different seeds produced identical values"}
	return {"name": "test_different_seeds_diverge", "passed": true}

static func _test_range_bounds() -> Dictionary:
	var rng = RandomServiceClass.new(999)

	for i in range(500):
		var f: float = rng.rand_float()
		if f < 0.0 or f >= 1.0:
			return {"name": "test_range_bounds", "passed": false, "error": "rand_float out of bounds: %f" % f}

		var rf: float = rng.rand_range_float(10.5, 25.5)
		if rf < 10.5 or rf > 25.5:
			return {"name": "test_range_bounds", "passed": false, "error": "rand_range_float out of bounds: %f" % rf}

		var ri: int = rng.rand_range_int(3, 7)
		if ri < 3 or ri > 7:
			return {"name": "test_range_bounds", "passed": false, "error": "rand_range_int out of bounds: %d" % ri}

	return {"name": "test_range_bounds", "passed": true}

static func _test_pick_and_shuffle() -> Dictionary:
	var rng = RandomServiceClass.new(777)

	# Test empty pick
	if rng.pick([]) != null:
		return {"name": "test_pick_and_shuffle", "passed": false, "error": "pick from empty array did not return null"}

	var items: Array = ["A", "B", "C", "D", "E"]
	for i in range(50):
		var p: Variant = rng.pick(items)
		if not items.has(p):
			return {"name": "test_pick_and_shuffle", "passed": false, "error": "picked invalid item: %s" % str(p)}

	# Test deterministic shuffle
	var arr1: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var arr2: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var rng_a = RandomServiceClass.new(888)
	var rng_b = RandomServiceClass.new(888)

	rng_a.shuffle(arr1)
	rng_b.shuffle(arr2)

	if arr1 != arr2:
		return {"name": "test_pick_and_shuffle", "passed": false, "error": "shuffle with same seed produced different order"}

	var sorted_arr: Array = arr1.duplicate()
	sorted_arr.sort()
	if sorted_arr != [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		return {"name": "test_pick_and_shuffle", "passed": false, "error": "shuffle corrupted items"}

	return {"name": "test_pick_and_shuffle", "passed": true}

static func _test_reset() -> Dictionary:
	var seed_val: int = 54321
	var rng = RandomServiceClass.new(seed_val)

	var first_run: Array[float] = []
	for i in range(20):
		first_run.append(rng.rand_float())

	rng.reset()

	var second_run: Array[float] = []
	for i in range(20):
		second_run.append(rng.rand_float())

	for i in range(20):
		if not is_equal_approx(first_run[i], second_run[i]):
			return {"name": "test_reset", "passed": false, "error": "reset() did not reproduce identical sequence"}

	return {"name": "test_reset", "passed": true}

