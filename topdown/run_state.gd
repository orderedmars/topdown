extends Node

# Run-scoped state. Wiped when a new run begins (after the player permadies).
# Cross-run persistence (achievements, unlocked content) lives elsewhere.

signal run_started
signal run_ended
signal karma_changed(new_value: int)
signal strength_rep_changed(new_value: int)
signal gold_changed(new_value: int)
signal floor_changed(new_value: int)

var player_adventurer: AdventurerData = null
var party: Array[AdventurerData] = []
var roster: Array[AdventurerData] = []  # all hired this run; party is a subset
var strength_rep: int = 0
var karma: int = 0  # negative = evil, positive = good
var gold: int = 100
var current_floor: int = 0  # 0 = not in dungeon, 1..10 = floor depth
var active_modifiers: Array[RunModifier] = []


func start_new_run(player: AdventurerData) -> void:
	player_adventurer = player
	party = [player]
	roster = [player]
	strength_rep = 0
	karma = 0
	gold = 100
	current_floor = 0
	active_modifiers.clear()
	run_started.emit()


func end_run() -> void:
	player_adventurer = null
	party.clear()
	roster.clear()
	strength_rep = 0
	karma = 0
	gold = 0
	current_floor = 0
	active_modifiers.clear()
	run_ended.emit()


func adjust_karma(delta: int) -> void:
	karma += delta
	karma_changed.emit(karma)


func adjust_strength_rep(delta: int) -> void:
	strength_rep += delta
	strength_rep_changed.emit(strength_rep)


func adjust_gold(delta: int) -> void:
	gold += delta
	gold_changed.emit(gold)


func enter_floor(floor_num: int) -> void:
	current_floor = floor_num
	floor_changed.emit(floor_num)


func exit_dungeon() -> void:
	current_floor = 0
	floor_changed.emit(0)
