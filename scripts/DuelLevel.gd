class_name DuelLevel
extends Level
## The 1v1 duel lot: a timed shift with no win or loss, only earnings. The queue length and
## retrievals follow the duel's minutes, and the result never touches campaign progress.

var minutes := 3  # duel length, set before the level enters the tree


## Draws enough customers for the whole duel from the pool. No space classes: far more ships
## arrive than the lot holds at once, so a draw that had to fit them all would stop early.
func prepare_queue() -> void:
	customer_queue = draw_customers(_pool, GameState.duel_customers(minutes), _rng)
	retrieval_count = GameState.duel_retrievals(minutes)
	if _exit:
		_retrieval_indexes = _pick_retrievals(customer_queue.size(), retrieval_count)


## A duel ledger that only the clock ends.
func new_ledger() -> ShiftLedger:
	return ShiftLedger.duel(minutes * 60.0)


## Stops the shift without recording campaign progress, stars or a result screen.
func end_level() -> void:
	if _ended:
		return
	_ended = true
	for v in valets:
		release_ship(v)
	Sound.stop_thruster()
