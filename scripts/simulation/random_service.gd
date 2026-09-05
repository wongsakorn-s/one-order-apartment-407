class_name RandomService
extends RefCounted

## Centralized deterministic random service for the simulation.
## Ensures all randomness is derived deterministically from a given integer seed.
## Prevents direct or accidental usage of global randomize() in simulation logic.

var _rng: RandomNumberGenerator
var _current_seed: int = 0

func _init(initial_seed: int = 12345) -> void:
	_rng = RandomNumberGenerator.new()
	set_seed(initial_seed)

## Set the active seed and re-initialize the internal generator.
func set_seed(p_seed: int) -> void:
	_current_seed = p_seed
	_rng.seed = p_seed

## Return the integer seed configured for this service.
func get_seed() -> int:
	return _current_seed

## Reset generator state back to the beginning of the configured seed sequence.
func reset() -> void:
	_rng.seed = _current_seed

## Return a pseudo-random float between 0.0 (inclusive) and 1.0 (exclusive).
func rand_float() -> float:
	return _rng.randf()

## Return a pseudo-random float within the range [from, to].
func rand_range_float(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

## Return a pseudo-random integer within the range [from, to] (inclusive).
func rand_range_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

## Pick a random element from the provided array. Returns null if array is empty.
func pick(array: Array) -> Variant:
	if array.is_empty():
		return null
	var index: int = _rng.randi_range(0, array.size() - 1)
	return array[index]

## Shuffle an array in-place using deterministic Fisher-Yates algorithm.
func shuffle(array: Array) -> void:
	var count: int = array.size()
	for i in range(count - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var temp: Variant = array[i]
		array[i] = array[j]
		array[j] = temp

