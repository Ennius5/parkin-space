class_name Customer
extends RefCounted
## One customer's visit: their tier and tip, how long they've waited, and whether they
## want their ship back. Pure data and rules; the Level drives it.

enum Tier { NONE, BRONZE, SILVER, GOLD }

const TIER_WEIGHTS := {Tier.BRONZE: 30, Tier.SILVER: 50, Tier.GOLD: 20}
const TIER_COLORS := {
	Tier.BRONZE: Color(0.8, 0.5, 0.2),
	Tier.SILVER: Color(0.8, 0.82, 0.86),
	Tier.GOLD: Color(1, 0.82, 0.2),
}
const BRONZE_TIP := 10
const SILVER_TIP := 15
const SILVER_DENT_COST := 5
const GOLD_TIP := 40
const GOLD_PATIENCE := 10.0  # seconds of waiting before the gold tip starts to shrink
const GOLD_DROP_PER_SECOND := 4
const REQUEST_DELAY_MIN := 20.0
const REQUEST_DELAY_MAX := 40.0
const REQUEST_TIME_RESERVE := 30.0  # a retrieval request always leaves this long to finish it

var tier: Tier = Tier.NONE
var bronze_tips := false  # rolled at spawn: a bronze customer tips half the time
var wants_retrieval := false
var requested := false
var request_in := -1.0  # seconds until the retrieval request; below 0 = none scheduled
var dents := 0
var wait := 0.0  # seconds spent waiting on the valet
var parked_in_gold := false
var parked_once := false


static func roll(rng: RandomNumberGenerator, use_tiers: bool, gold_allowed := true) -> Customer:
	var c := Customer.new()
	if use_tiers:
		var tiers := TIER_WEIGHTS.keys()
		if not gold_allowed:
			tiers.erase(Tier.GOLD)
		var weights := PackedFloat32Array()
		for t in tiers:
			weights.append(TIER_WEIGHTS[t])
		c.tier = tiers[rng.rand_weighted(weights)]
		c.bronze_tips = rng.randf() < 0.5
	return c


func tip() -> int:
	if tier == Tier.GOLD and not parked_in_gold:
		return 0
	return tip_on_offer()


## The tip as it stands, before the gold-space rule: what a gold badge shows while waiting.
func tip_on_offer() -> int:
	match tier:
		Tier.BRONZE:
			return BRONZE_TIP if bronze_tips else 0
		Tier.SILVER:
			return maxi(0, SILVER_TIP - SILVER_DENT_COST * dents)
		Tier.GOLD:
			return maxi(0, GOLD_TIP - GOLD_DROP_PER_SECOND * ceili(maxf(0.0, wait - GOLD_PATIENCE)))
	return 0


## What the badge shows: the tip on offer while waiting to park, then what will actually be paid.
func tip_shown() -> int:
	return tip() if parked_once else tip_on_offer()


## Waiting from arrival until parked, and again from a retrieval request until returned.
func is_waiting() -> bool:
	return not parked_once or requested


func color() -> Color:
	return TIER_COLORS.get(tier, Color.TRANSPARENT)


## Seconds from parking until the retrieval request, never leaving less than
## REQUEST_TIME_RESERVE of the shift to finish it.
static func request_delay(rng: RandomNumberGenerator, time_left: float) -> float:
	var delay := rng.randf_range(REQUEST_DELAY_MIN, REQUEST_DELAY_MAX)
	return minf(delay, maxf(0.0, time_left - REQUEST_TIME_RESERVE))
