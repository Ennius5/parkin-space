class_name BaySlots
extends RefCounted
## The duel's seeded arrival list for its two bays (pure, no nodes). Slot N brings a ship of the
## same class and a customer of the same tier to both bays; each bay draws its own model.


## count slot pairs drawn from pool with rng. Each entry is [left, right], both
## {spec, tier, bronze_tips}. The class follows a spawn-weighted pick from the whole pool; each
## bay's model is a spawn-weighted pick among the ships of that class. The tier is rolled once
## per slot, and gold only where gold_allowed.call(ship_class) says so.
static func build(pool: Array[ShipSpec], count: int, rng: RandomNumberGenerator, gold_allowed: Callable,
		use_tiers: bool, tier_weights: Dictionary) -> Array:
	var slots: Array = []
	if pool.is_empty():
		return slots
	for i in count:
		var left := _pick(pool, rng, -1)
		var right := _pick(pool, rng, left.ship_class)
		var c := Customer.roll(rng, use_tiers, gold_allowed.call(left.ship_class), tier_weights)
		slots.append([_entry(left, c), _entry(right, c)])
	return slots


## A spawn-weighted pick from pool, only among ships of ship_class unless it is -1.
static func _pick(pool: Array[ShipSpec], rng: RandomNumberGenerator, ship_class: int) -> ShipSpec:
	var options: Array[ShipSpec] = []
	var weights := PackedFloat32Array()
	for spec in pool:
		if ship_class < 0 or spec.ship_class == ship_class:
			options.append(spec)
			weights.append(spec.spawn_weight)
	return options[rng.rand_weighted(weights)]


static func _entry(spec: ShipSpec, c: Customer) -> Dictionary:
	return {"spec": spec, "tier": c.tier, "bronze_tips": c.bronze_tips}
