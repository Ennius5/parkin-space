class_name Valet
extends RefCounted
## One player in the lot: the ship they drive, their score and where their buttons come from.
## Offline there is one local valet; a duel adds a rival driven over the network.

var id: int
var ship: Ship = null  # the ship this valet drives right now
var ledger: ShiftLedger
var pilot: ShipPilot
var local: bool  # plays on this device: owns the controls, camera and hints
var released_at_msec := -Level.RESELECT_DELAY_MS  # when Done last let go of a ship


func _init(valet_id := 0, is_local := true, valet_ledger: ShiftLedger = null, valet_pilot: ShipPilot = null) -> void:
	id = valet_id
	local = is_local
	ledger = valet_ledger
	if valet_pilot:
		pilot = valet_pilot
	elif is_local:
		pilot = LocalPilot.new()
	else:
		pilot = ShipPilot.new()
