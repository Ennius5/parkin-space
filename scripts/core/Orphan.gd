class_name Orphan
extends RefCounted
## An ownerless ship's paperwork: once its countdown runs out, ejecting it at the EXIT pays a
## removal bonus; ejecting it sooner costs pay.

const COUNTDOWN := 60.0
const BONUS := 25
const EARLY_COST := 15

var time_left := COUNTDOWN


func tick(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)


func ready_to_eject() -> bool:
	return time_left <= 0.0


func badge_text() -> String:
	if ready_to_eject():
		return "EJECT ✓"
	var s := ceili(time_left)
	return "%d:%02d" % [s / 60, s % 60]
