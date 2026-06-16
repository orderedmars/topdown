extends CanvasLayer

# Turn-based 1v1 battle for the foundation system. The collaborator will likely
# replace large chunks of this (damage formulas, action economy, multi-target
# resolution, skill catalog) — what's important here is the shape:
#
#   _ready
#     -> snapshot enemy + player into Combatant dicts
#     -> roll initiative to decide turn order
#     -> _advance_turn  ──▶  player turn: enable AttackButton, await press
#                       └──▶  enemy turn: pick action, resolve, advance
#     -> end on either combatant hp <= 0
#         -> BattleManager.finish_victory   (kills enemy node in dungeon)
#         -> BattleManager.finish_defeat    (ends the run; permadeath)

const TURN_PAUSE := 0.6   # readability gap between actions
const VICTORY_DELAY := 1.4
const DEFEAT_DELAY := 2.0

enum Side { PLAYER, ENEMY }

var _player: Dictionary = {}
var _enemy: Dictionary = {}
var _turn_order: Array = []   # Side values; untyped so literal `[a, b]` assignment works
var _turn_index: int = 0
var _awaiting_input: bool = false
var _battle_over: bool = false

@onready var _enemy_name: Label = $Main/EnemyArea/EnemyBox/EnemyName
@onready var _enemy_hp: ProgressBar = $Main/EnemyArea/EnemyBox/EnemyHP
@onready var _enemy_effects: Label = $Main/EnemyArea/EnemyBox/EnemyEffects
@onready var _enemy_sprite: ColorRect = $Main/EnemyArea/EnemyBox/EnemySprite
@onready var _player_name: Label = $Main/PlayerArea/PlayerBox/PlayerName
@onready var _player_hp: ProgressBar = $Main/PlayerArea/PlayerBox/PlayerHP
@onready var _player_effects: Label = $Main/PlayerArea/PlayerBox/PlayerEffects
@onready var _player_sprite: ColorRect = $Main/PlayerArea/PlayerBox/PlayerSprite
@onready var _log_box: RichTextLabel = $Main/BattleLog
@onready var _attack_btn: Button = $Main/ActionMenu/AttackButton


func _ready() -> void:
	_attack_btn.pressed.connect(_on_attack_pressed)
	_build_combatants()
	_roll_initiative()
	_refresh_ui()
	_log("A %s blocks your path!" % _enemy["name"])
	if _enemy["effects"].size() > 0:
		_log("It's already suffering — your skill landed.")
	if _enemy["hp"] < _enemy["max_hp"]:
		_log("(%s starts at %d / %d HP.)" % [_enemy["name"], int(_enemy["hp"]), int(_enemy["max_hp"])])
	_log("Initiative: %s." % ("you act first" if _turn_order[0] == Side.PLAYER else "%s acts first" % _enemy["name"]))
	await get_tree().create_timer(0.6).timeout
	_advance_turn()


func _build_combatants() -> void:
	var enemy_node: Node = BattleManager.current_enemy
	_enemy = {
		"name": enemy_node.display_name,
		"hp": enemy_node.health,
		"max_hp": enemy_node.max_health,
		"attack": enemy_node.attack_damage,
		"initiative": enemy_node.combat_initiative,
		"effects": _duplicate_effects(enemy_node.effects),
		"side": Side.ENEMY,
	}

	var ad: AdventurerData = RunState.player_adventurer
	var player_node: Node = get_tree().get_first_node_in_group("player")
	var name_str: String = "Player"
	var dex: int = 10
	var strength: int = 10
	var max_hp_val: float = 100.0
	if ad != null:
		name_str = ad.display_name
		dex = ad.dexterity
		strength = ad.strength
		max_hp_val = float(ad.max_health)
	elif player_node != null and "max_health" in player_node:
		max_hp_val = player_node.max_health
	var current_hp_val: float = max_hp_val
	if player_node != null and "health" in player_node:
		current_hp_val = player_node.health
	_player = {
		"name": name_str,
		"hp": current_hp_val,
		"max_hp": max_hp_val,
		"attack": float(strength),
		"initiative": dex,
		"effects": [] as Array[Dictionary],
		"side": Side.PLAYER,
	}


func _duplicate_effects(src: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in src:
		out.append((e as Dictionary).duplicate(true))
	return out


# Each side rolls initiative + d6. Higher acts first; ties go to the player.
func _roll_initiative() -> void:
	var pr: int = int(_player["initiative"]) + (randi() % 6) + 1
	var er: int = int(_enemy["initiative"]) + (randi() % 6) + 1
	_turn_order = [Side.PLAYER, Side.ENEMY] if pr >= er else [Side.ENEMY, Side.PLAYER]
	_turn_index = 0


func _advance_turn() -> void:
	if _battle_over:
		return
	var actor: int = _turn_order[_turn_index % _turn_order.size()]
	var combatant: Dictionary = _player if actor == Side.PLAYER else _enemy
	_tick_effects(combatant)
	_refresh_ui()
	if _check_battle_end():
		return
	if actor == Side.PLAYER:
		_begin_player_turn()
	else:
		_begin_enemy_turn()


func _begin_player_turn() -> void:
	_log("Your turn.")
	_awaiting_input = true
	_attack_btn.disabled = false
	_attack_btn.grab_focus()


func _begin_enemy_turn() -> void:
	_awaiting_input = false
	_attack_btn.disabled = true
	await get_tree().create_timer(TURN_PAUSE).timeout
	if _battle_over:
		return
	var dmg: int = _roll_damage(_enemy["attack"])
	_apply_damage(_player, dmg)
	_log("%s hits you for %d." % [_enemy["name"], dmg])
	_refresh_ui()
	await get_tree().create_timer(TURN_PAUSE).timeout
	_turn_index += 1
	_advance_turn()


func _on_attack_pressed() -> void:
	if not _awaiting_input or _battle_over:
		return
	_awaiting_input = false
	_attack_btn.disabled = true
	var dmg: int = _roll_damage(_player["attack"])
	_apply_damage(_enemy, dmg)
	_log("You hit %s for %d." % [_enemy["name"], dmg])
	_refresh_ui()
	await get_tree().create_timer(TURN_PAUSE).timeout
	_turn_index += 1
	_advance_turn()


# Damage = base ± d4-ish jitter, floored at 1. The collaborator will likely
# rewrite this with proper to-hit + defense + crit. Keeping it simple so the
# loop is observable.
func _roll_damage(base: float) -> int:
	var roll: float = base + randf_range(-1.0, 3.0)
	return maxi(1, int(round(roll)))


func _apply_damage(combatant: Dictionary, dmg: int) -> void:
	combatant["hp"] = maxf(0.0, float(combatant["hp"]) - dmg)


# Per-turn status tick. Only "poison" is implemented as a proof-of-concept;
# wire new effect types here (or move to a dispatcher when there are 3+).
func _tick_effects(combatant: Dictionary) -> void:
	var kept: Array[Dictionary] = []
	for effect: Dictionary in combatant["effects"]:
		var etype: String = String(effect.get("type", ""))
		if etype == "poison":
			var dpt: int = int(effect.get("damage_per_turn", 2))
			combatant["hp"] = maxf(0.0, float(combatant["hp"]) - dpt)
			_log("%s takes %d poison damage." % [combatant["name"], dpt])
		var turns: int = int(effect.get("turns", 0)) - 1
		if turns > 0:
			effect["turns"] = turns
			kept.append(effect)
	combatant["effects"] = kept


func _check_battle_end() -> bool:
	if float(_player["hp"]) <= 0.0:
		_battle_over = true
		_log("You collapse. The run ends here.")
		_refresh_ui()
		_attack_btn.disabled = true
		_finish_defeat_after_delay()
		return true
	if float(_enemy["hp"]) <= 0.0:
		_battle_over = true
		_log("Victory! %s falls." % _enemy["name"])
		_refresh_ui()
		_attack_btn.disabled = true
		_finish_victory_after_delay()
		return true
	return false


func _finish_victory_after_delay() -> void:
	# Persist final player HP back to the player node so dungeon healing/dying
	# in the next encounter starts from the right place.
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node != null and "health" in player_node:
		player_node.health = float(_player["hp"])
	await get_tree().create_timer(VICTORY_DELAY).timeout
	BattleManager.finish_victory()


func _finish_defeat_after_delay() -> void:
	await get_tree().create_timer(DEFEAT_DELAY).timeout
	BattleManager.finish_defeat()


func _log(text: String) -> void:
	if _log_box.text.is_empty():
		_log_box.text = text
	else:
		_log_box.text += "\n" + text


func _refresh_ui() -> void:
	_enemy_name.text = String(_enemy["name"])
	_enemy_hp.max_value = float(_enemy["max_hp"])
	_enemy_hp.value = float(_enemy["hp"])
	_enemy_effects.text = _effects_summary(_enemy["effects"])
	_player_name.text = String(_player["name"])
	_player_hp.max_value = float(_player["max_hp"])
	_player_hp.value = float(_player["hp"])
	_player_effects.text = _effects_summary(_player["effects"])


func _effects_summary(effects: Array) -> String:
	if effects.is_empty():
		return ""
	var parts: Array[String] = []
	for e: Dictionary in effects:
		parts.append("%s (%d)" % [String(e.get("type", "?")), int(e.get("turns", 0))])
	return "Effects: " + ", ".join(parts)
