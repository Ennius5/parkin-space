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


func test_add_fee_does_not_serve() -> void:
	var l := ShiftLedger.new(100, 1, 180.0)
	l.add_fee()
	assert_eq(l.earned, ShiftLedger.PARK_FEE)
	assert_eq(l.served, 0)
	assert_eq(l.outcome, ShiftLedger.Outcome.PLAYING)


func test_add_tip_counts_in_earnings() -> void:
	var l := ShiftLedger.new(100, 2, 180.0)
	l.add_tip(15)
	assert_eq(l.tips, 15)
	assert_eq(l.earned, 15)
	assert_eq(l.earnings(), 115)


func test_leaver_flow_wins_on_return() -> void:
	var l := ShiftLedger.new(100, 1, 180.0)
	l.add_fee()
	assert_eq(l.outcome, ShiftLedger.Outcome.PLAYING)
	l.serve_customer(0)
	assert_eq(l.outcome, ShiftLedger.Outcome.WON)
	assert_eq(l.earned, 20)


func test_no_money_after_outcome() -> void:
	var l := ShiftLedger.new(100, 1, 180.0)
	l.serve_customer()
	l.add_fee()
	l.add_tip(10)
	assert_eq(l.earned, 20)
	assert_eq(l.tips, 0)


func test_ledger_bonus_adds_to_earnings() -> void:
	var l := ShiftLedger.new(100, 1, 60.0)
	l.add_bonus(25)
	assert_eq(l.bonuses, 25)
	assert_eq(l.earned, 25)
	l.serve_customer()
	l.add_bonus(25)
	assert_eq(l.bonuses, 25, "ignored once the shift is won")
