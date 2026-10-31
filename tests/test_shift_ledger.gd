extends TestCase


func test_dent_cost_curve() -> void:
	assert_eq(ShiftLedger.dent_cost(120.0), 0)
	assert_eq(ShiftLedger.dent_cost(121.0), 5)
	assert_eq(ShiftLedger.dent_cost(200.0), 25)


func test_serving_all_customers_wins() -> void:
	var l := ShiftLedger.new(100, 2, 180.0)
	l.serve_customer()
	assert_eq(l.outcome, ShiftLedger.Outcome.PLAYING)
	l.serve_customer()
	assert_eq(l.outcome, ShiftLedger.Outcome.WON)
	assert_eq(l.earnings(), 140)


func test_pay_zero_fires() -> void:
	var l := ShiftLedger.new(100, 4, 180.0)
	l.add_dent(60)
	l.add_dent(60)
	assert_eq(l.pay, 0)
	assert_eq(l.outcome, ShiftLedger.Outcome.FIRED)


func test_timeout() -> void:
	var l := ShiftLedger.new(100, 4, 1.0)
	l.tick(0.6)
	l.tick(0.6)
	assert_eq(l.time_left, 0.0)
	assert_eq(l.outcome, ShiftLedger.Outcome.TIMEOUT)


func test_outcome_is_final() -> void:
	var l := ShiftLedger.new(100, 1, 1.0)
	l.serve_customer()
	l.tick(5.0)
	l.add_dent(500)
	assert_eq(l.outcome, ShiftLedger.Outcome.WON)
	assert_eq(l.pay, 100)


func test_stars() -> void:
	assert_eq(ShiftLedger.stars_for(180, 150, 170, true), 3)
	assert_eq(ShiftLedger.stars_for(160, 150, 170, true), 2)
	assert_eq(ShiftLedger.stars_for(120, 150, 170, true), 1)
	assert_eq(ShiftLedger.stars_for(180, 150, 170, false), 0)
