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
	c.wait = 14.9
	assert_eq(c.tip(), 40)
	c.wait = 15.0
	assert_eq(c.tip(), 36)  # ₵4 lost every 5 s after the first 10 s
	c.wait = 22.0
	assert_eq(c.tip(), 32)
	c.wait = 59.9
	assert_eq(c.tip(), 4)
	c.wait = 60.0
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
	c.wait = 17.0
	assert_eq(c.tip(), 0)
	assert_eq(c.tip_on_offer(), 36)


func test_roll_without_gold_never_gold() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 85
	var silver := 0
	for i in 500:
		var tier := Customer.roll(rng, true, false).tier
		assert_true(tier == Customer.Tier.BRONZE or tier == Customer.Tier.SILVER)
		if tier == Customer.Tier.SILVER:
			silver += 1
	assert_true(silver > 250, "silver %d" % silver)  # bronze:silver stays 30:50


func test_tip_shown_after_parking_is_what_gets_paid() -> void:
	var c := _customer(Customer.Tier.GOLD)
	c.wait = 5.0
	assert_eq(c.tip_shown(), 40)  # still waiting: the tip on offer
	c.parked_once = true
	assert_eq(c.tip_shown(), 0)  # parked outside a gold space
	c.parked_in_gold = true
	assert_eq(c.tip_shown(), 40)


const GOLD_RUSH := {Customer.Tier.GOLD: 60, Customer.Tier.SILVER: 30, Customer.Tier.BRONZE: 10}


func _shares(weights: Dictionary, gold_allowed: bool, rolls: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var counts := {Customer.Tier.GOLD: 0, Customer.Tier.SILVER: 0, Customer.Tier.BRONZE: 0}
	for i in rolls:
		counts[Customer.roll(rng, true, gold_allowed, weights).tier] += 1
	for t in counts:
		counts[t] = float(counts[t]) / rolls
	return counts


func test_custom_tier_weights() -> void:
	var s := _shares(GOLD_RUSH, true, 2000)
	assert_true(s[Customer.Tier.GOLD] > 0.55 and s[Customer.Tier.GOLD] < 0.65, str(s))
	assert_true(s[Customer.Tier.BRONZE] > 0.07 and s[Customer.Tier.BRONZE] < 0.13, str(s))


func test_default_tier_weights_unchanged() -> void:
	var s := _shares({}, true, 2000)
	assert_true(s[Customer.Tier.GOLD] > 0.16 and s[Customer.Tier.GOLD] < 0.24, str(s))


func test_custom_weights_still_respect_gold_fit() -> void:
	assert_eq(_shares(GOLD_RUSH, false, 200)[Customer.Tier.GOLD], 0.0)
