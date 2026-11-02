extends TestCase


func test_countdown_runs_a_minute_then_ejects() -> void:
	var o := Orphan.new()
	assert_eq(o.badge_text(), "1:00")
	assert_false(o.ready_to_eject())
	o.tick(59.5)
	assert_eq(o.badge_text(), "0:01")
	assert_false(o.ready_to_eject())
	o.tick(0.5)
	assert_eq(o.badge_text(), "EJECT ✓")
	assert_true(o.ready_to_eject())
	o.tick(5.0)
	assert_eq(o.time_left, 0.0)
