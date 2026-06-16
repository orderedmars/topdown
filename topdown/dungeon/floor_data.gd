class_name FloorData
extends Resource

# One per floor of the 10-floor descent. Defines the floor's identity, content
# pools, and room composition. Floor order is fixed — `floor_number` is the
# slot, not a mutable depth.

@export var floor_number: int = 1  # 1..10
@export var theme_name: String = "Floor"
@export_multiline var description: String = ""

@export_group("Visuals")
@export var background_color: Color = Color(0.05, 0.05, 0.07, 1)
@export var wall_color: Color = Color(0.15, 0.1, 0.15, 1)
@export var floor_color: Color = Color(0.2, 0.18, 0.2, 1)

@export_group("Pools")
# Enemies that can spawn in enemy rooms. Currently PackedScene refs;
# may switch to an EnemyData resource later.
@export var enemy_pool: Array[PackedScene] = []
@export var miniboss_pool: Array[PackedScene] = []
@export var boss_scene: PackedScene
@export var loot_pool: LootTable
@export var encounter_pool: Array[EncounterData] = []

@export_group("Room Templates")
# Templates the generator picks from per room type. Filtered by room_type at gen time.
@export var room_templates: Array[RoomTemplate] = []

@export_group("Room Counts")
# Mandatory minimums per floor. Total fixed mandatory = 16:
#   1 entry + 1 campsite + 5 enemy + 2 miniboss + 3 random encounter
#   + 2 chest + 1 merchant + 1 boss
# Modifiers may override.
@export var entry_room_count: int = 1
@export var campsite_room_count: int = 1
@export var enemy_room_min: int = 5
@export var miniboss_room_min: int = 2
@export var random_encounter_min: int = 3
@export var chest_room_min: int = 2
@export var merchant_room_count: int = 1
@export var boss_room_count: int = 1

# Extras rolled at gen time: a random count in [extra_room_min, extra_room_max].
# Each extra slot draws from {CAMPSITE, RANDOM_ENCOUNTER, MINIBOSS, ENEMY, CHEST}.
# Default 0-5 → total floor rooms in [16, 21].
@export var extra_room_min: int = 0
@export var extra_room_max: int = 5

@export_group("Spawning")
# How many enemies appear in each ENEMY room. Rolled per room at reveal time.
@export var enemies_per_room_min: int = 2
@export var enemies_per_room_max: int = 4
# How many minibosses appear in each MINIBOSS room. Usually 1.
@export var minibosses_per_room_min: int = 1
@export var minibosses_per_room_max: int = 1

@export_group("Per-Floor Modifiers")
# Always-on modifiers for this floor (e.g. "all enemies are undead").
@export var built_in_modifiers: Array[RunModifier] = []
