class_name RoomTemplate
extends Resource

# Defines a room the macro generator can place. Templates are picked by
# (room_type, room_size). The interior is either:
#   - hand-authored via `prefab_scene` (placed verbatim), or
#   - generated procedurally via cellular automata using the parameters below.
#
# Room types:
#   ENTRY            spawn point + exit portal back to town (1 per floor)
#   CAMPSITE         rest room; restores a small amount of HP/mana (1 per floor)
#   ENEMY            combat from floor's enemy pool (>=5 per floor)
#   MINIBOSS         tougher curated combat (>=2 per floor)
#   RANDOM_ENCOUNTER event from floor's encounter pool (>=3 per floor)
#   CHEST            guaranteed loot drop, no enemies (>=2 per floor)
#   MERCHANT         small in-dungeon vendor (1 per floor)
#   BOSS             single boss; defeat opens portal to next floor (1 per floor)
#
# Per-floor composition: 16 mandatory + 0-5 extras = 16-21 rooms total.
# Extras pool: CAMPSITE, RANDOM_ENCOUNTER, MINIBOSS, ENEMY, CHEST.

enum RoomType {
	ENTRY,
	CAMPSITE,
	ENEMY,
	MINIBOSS,
	RANDOM_ENCOUNTER,
	CHEST,
	MERCHANT,
	BOSS,
}

enum RoomSize { SMALL, MEDIUM, LARGE }

@export var room_type: RoomType = RoomType.ENEMY
@export var room_size: RoomSize = RoomSize.MEDIUM

# Tile dimensions for procedural generation. Ignored if `prefab_scene` is set
# (the prefab dictates its own size).
@export var tile_width: int = 12
@export var tile_height: int = 8

# Optional hand-authored interior. If set, generator uses this as-is.
@export var prefab_scene: PackedScene

@export_group("Cellular Automata")
# Used only when `prefab_scene` is null.
@export_range(0.0, 1.0) var initial_wall_chance: float = 0.45
@export var smoothing_iterations: int = 4

@export_group("Selection Weight")
# Higher weight = more likely to be picked when multiple templates match
# (room_type, room_size). 0 = never picked.
@export var weight: float = 1.0
