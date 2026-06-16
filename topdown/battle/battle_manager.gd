extends Node

# Orchestrates the transition between the dungeon and the turn-based battle
# scene. Owns the "is a battle happening right now" flag (only one at a time)
# and handles post-battle cleanup: kill the enemy on victory, end the run on
# defeat. The battle scene itself owns the in-fight logic.

signal battle_started(enemy_node)
signal battle_ended(player_won: bool)

const BATTLE_SCENE := preload("res://battle/battle_scene.tscn")
const GAME_OVER_SCENE := "res://ui/character_creation.tscn"

var current_enemy: Node = null
var is_in_battle: bool = false
var _battle_instance: Node = null


# Called from enemy melee Area2D or from a skill that landed a hit. Pauses the
# dungeon and overlays the battle scene. Ignored if a battle is already running
# or if the enemy node was freed (e.g., killed by the same skill that triggered).
func start_battle(enemy_node: Node) -> void:
	if is_in_battle:
		return
	if not is_instance_valid(enemy_node):
		return
	is_in_battle = true
	current_enemy = enemy_node
	get_tree().paused = true
	_battle_instance = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(_battle_instance)
	battle_started.emit(enemy_node)


# Called by the battle scene when the enemy's HP hits 0. Drops loot via the
# enemy's normal die() path so a battle kill is indistinguishable from a
# dungeon kill from the loot system's perspective.
func finish_victory() -> void:
	if not is_in_battle:
		return
	_teardown_battle()
	if is_instance_valid(current_enemy):
		current_enemy.die()
	current_enemy = null
	battle_ended.emit(true)


# Called by the battle scene when the player party is wiped. Ends the run
# (permadeath) and bounces back to character creation.
func finish_defeat() -> void:
	if not is_in_battle:
		return
	_teardown_battle()
	current_enemy = null
	battle_ended.emit(false)
	RunState.end_run()
	get_tree().change_scene_to_file(GAME_OVER_SCENE)


func _teardown_battle() -> void:
	is_in_battle = false
	if _battle_instance != null:
		_battle_instance.queue_free()
		_battle_instance = null
	get_tree().paused = false
