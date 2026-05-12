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
# Mandatory per floor — Isaac-style split. Plus 1 entry. Total 13 mandatory.
# Modifiers may override.
@export var enemy_room_count: int = 6
@export var miniboss_room_count: int = 2
@export var random_encounter_count: int = 3
@export var boss_room_count: int = 1
# Extras drawn at random from non-mandatory templates in `room_templates`
# (treasure / shop / curse / altar / library / trap_gauntlet / statue / vault).
# Default 5 per floor → 18 rooms total.
@export var extra_room_count: int = 5

@export_group("Per-Floor Modifiers")
# Always-on modifiers for this floor (e.g. "all enemies are undead").
@export var built_in_modifiers: Array[RunModifier] = []
