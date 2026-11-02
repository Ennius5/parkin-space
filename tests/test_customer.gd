extends TestCase


func _customer(tier: Customer.Tier) -> Customer:
	var c := Customer.new()
	c.tier = tier
	return c


func test_none_tier_never_tips() -> void:
	var c := _customer(Customer.Tier.NONE)
	c.parked_in_gold = true
	assert_eq(c.tip(), 0)


func test_bronze_tip_follows_roll() -> void:
	var c := _customer(Customer.Tier.BRONZE)
	c.bronze_tips = true
	assert_eq(c.tip(), 10)
	c.bronze_tips = false
	assert_eq(c.tip(), 0)


func test_silver_tip_drops_per_dent() -> void:
	var c := _customer(Customer.Tier.SILVER)
	assert_eq(c.tip(), 15)
	c.dents = 2
	assert_eq(c.tip(), 5)
	c.dents = 4
	assert_eq(c.tip(), 0)


func test_gold_needs_gold_space() -> void:
	var c := _customer(Customer.Tier.GOLD)
	c.wait = 5.0
	assert_eq(c.tip(), 0)
	c.parked_in_gold = true
	assert_eq(c.tip(), 40)


func test_gold_tip_shrinks_after_ten_seconds() -> void:
	var c := _customer(Customer.Tier.GOLD)
	c.parked_in_gold = true
	c.wait = 10.0
	assert_eq(c.tip(), 40)
	c.wait = 12.5
	assert_eq(c.tip(), 28)
	c.wait = 25.0
	assert_eq(c.tip(), 0)


func test_tier_mix() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 85
	var counts := {}
	for i in 2000:
		var tier := Customer.roll(rng, true).tier
		counts[tier] = counts.get(tier, 0) + 1
	var gold: float = counts.get(Customer.Tier.GOLD, 0) / 2000.0
	var silver: float = counts.get(Customer.Tier.SILVER, 0) / 2000.0
	assert_true(gold >= 0.17 and gold <= 0.23, "gold share %f" % gold)
	assert_true(silver >= 0.46 and silver <= 0.54, "silver share %f" % silver)
	assert_false(counts.has(Customer.Tier.NONE))


func test_no_tiers_rolls_none() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 20:
		assert_eq(Customer.roll(rng, false).tier, Customer.Tier.NONE)


func test_request_delay_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 85
	for i in 50:
		var d := Customer.request_delay(rng, 180.0)
		assert_true(d >= 20.0 and d <= 40.0, "delay %f" % d)


func test_request_delay_leaves_thirty_seconds() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 20:
		assert_true(Customer.request_delay(rng, 50.0) <= 20.0)
	assert_eq(Customer.request_delay(rng, 25.0), 0.0)


func test_is_waiting() -> void:
	var c := Customer.new()
	assert_true(c.is_waiting())
	c.parked_once = true
	assert_false(c.is_waiting())
	c.requested = true
	assert_true(c.is_waiting())


func test_tier_colors() -> void:
	assert_eq(_customer(Customer.Tier.GOLD).color(), Color(1, 0.82, 0.2))
	assert_eq(_customer(Customer.Tier.NONE).color().a, 0.0)


func test_gold_tip_on_offer_ignores_space() -> void:
	var c := _customer(Customer.Tier.GOLD)
	c.wait = 12.5
	assert_eq(c.tip(), 0)
	assert_eq(c.tip_on_offer(), 28)
