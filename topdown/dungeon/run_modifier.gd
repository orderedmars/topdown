class_name RunModifier
extends Resource

# A modifier active during a run (or specific floor). The actual gameplay
# effect is determined by `effect_id` — different systems (generator, spawner,
# combat) interpret known ids and apply behavior.

@export var modifier_name: String = "Modifier"
@export_multiline var description: String = ""

# Open-ended effect tag interpreted by the systems. Examples:
#   "enemy_damage_x2"
#   "all_enemy_rooms_are_minibosses"
#   "no_random_encounters"
#   "double_loot"
@export var effect_id: StringName = ""

# Numeric value some effects need (multiplier, count, threshold, etc.)
@export var effect_value: float = 1.0

@export_group("Scope")
# 0 = applies to the whole run. 1..10 = applies only on that floor.
@export_range(0, 10) var floor_scope: int = 0

@export_group("Quest Reward")
# Higher = harder; quest reward scales with this. 0 = built-in floor modifier.
@export var difficulty_weight: int = 1
