class_name TestCase
extends RefCounted
## Base class for tests. Assertions record failures instead of stopping the test.

var tree: SceneTree
var failures: Array[String] = []


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		_fail("expected %s (%s), got %s (%s) %s" % [expected, type_string(typeof(expected)), actual, type_string(typeof(actual)), msg])
	elif actual != expected:
		_fail("expected %s, got %s %s" % [expected, actual, msg])


func assert_almost(actual: float, expected: float, tolerance: float, msg := "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %s ± %s, got %s %s" % [expected, tolerance, actual, msg])


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		_fail("expected true %s" % msg)


func assert_false(cond: bool, msg := "") -> void:
	if cond:
		_fail("expected false %s" % msg)


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _fail(text: String) -> void:
	failures.append(text.strip_edges())
