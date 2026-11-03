class_name ShiftLedger
extends RefCounted
## Pay, tips, timer and outcome for one shift. Once the outcome is decided it never changes.

enum Outcome { PLAYING, WON, FIRED, TIMEOUT }

const SAFE_IMPACT_SPEED := 120.0  # px/s; slower bumps are free
const PARK_FEE := 20

var pay: int  # salary left after dents; reaching 0 = fired
var earned: int = 0  # fees and tips
var tips: int = 0
var bonuses: int = 0  # orphan removal bonuses
var served: int = 0
var customers: int
var time_left: float
var outcome: Outcome = Outcome.PLAYING
var endless := false  # duel mode: pay may go negative, no FIRED or WON; only the clock ends it


func _init(base_pay: int, customer_count: int, shift_seconds: float) -> void:
	pay = base_pay
	customers = customer_count
	time_left = shift_seconds


## A duel ledger: starts at 0, dents can push it negative, only the timer ends it.
static func duel(seconds: float) -> ShiftLedger:
	var l := ShiftLedger.new(0, 0, seconds)
	l.endless = true
	return l


func add_dent(cost: int) -> void:
	if outcome != Outcome.PLAYING:
		return
	if endless:
		pay -= cost
		return
	pay = maxi(pay - cost, 0)
	if pay == 0:
		outcome = Outcome.FIRED


## A park fee from a customer who isn't done yet (they'll want their ship back).
func add_fee(fee: int = PARK_FEE) -> void:
	if outcome != Outcome.PLAYING:
		return
	earned += fee


func add_tip(amount: int) -> void:
	if outcome != Outcome.PLAYING:
		return
	tips += amount
	earned += amount


## A removal bonus for an orphaned ship ejected on time.
func add_bonus(amount: int) -> void:
	if outcome != Outcome.PLAYING:
		return
	bonuses += amount
	earned += amount


func serve_customer(fee: int = PARK_FEE) -> void:
	if outcome != Outcome.PLAYING:
		return
	served += 1
	earned += fee
	if endless:
		return
	if served >= customers:
		outcome = Outcome.WON


func tick(delta: float) -> void:
	if outcome != Outcome.PLAYING:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left == 0.0:
		outcome = Outcome.TIMEOUT


func earnings() -> int:
	return pay + earned


static func dent_cost(impact_speed: float) -> int:
	if impact_speed <= SAFE_IMPACT_SPEED:
		return 0
	return 5 + int((impact_speed - SAFE_IMPACT_SPEED) * 0.25)


static func stars_for(total_earnings: int, silver: int, gold: int, won: bool) -> int:
	if not won:
		return 0
	if total_earnings >= gold:
		return 3
	if total_earnings >= silver:
		return 2
	return 1
