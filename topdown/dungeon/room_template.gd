class_name RoomTemplate
extends Resource

# Defines a room the macro generator can place. Templates are picked by
# (room_type, room_size). The interior is either:
#   - hand-authored via `prefab_scene` (placed verbatim), or
#   - generated procedurally via cellular automata using the parameters below.
#
# All room types the dungeon can generate:
#   ENTRY            spawn point + exit portal back to town (1 per floor)
#   ENEMY            combat from floor's enemy pool (6 per floor)
#   MINIBOSS         tougher curated combat (2 per floor)
#   RANDOM_ENCOUNTER event from floor's encounter pool (3 per floor)
#   BOSS             single boss; defeat unlocks stairs to next floor (1)
#   TREASURE         guaranteed loot drop, no enemies
#   SHOP             small in-dungeon vendor (potions, basic gear)
#   CURSE            pay HP / karma for a powerful reward
#   ALTAR            sacrifice an item to gain a blessing or buff
#   LIBRARY          random skill scroll or knowledge gain
#   TRAP_GAUNTLET    survive deadly traps for reward at the end
#   STATUE           lore room with small reward
#   VAULT            requires a key item; contains rare loot
#
# Mandatory per floor: ENTRY + ENEMY×6 + MINIBOSS×2 + RANDOM_ENCOUNTER×3 + BOSS
# = 13 rooms. Plus 5 extras drawn at random from the non-mandatory pool
# (TREASURE / SHOP / CURSE / ALTAR / LIBRARY / TRAP_GAUNTLET / STATUE / VAULT)
# → 18 rooms per floor.

enum RoomType {
	ENTRY,
	ENEMY,
	MINIBOSS,
	RANDOM_ENCOUNTER,
	BOSS,
	TREASURE,
	SHOP,
	CURSE,
	ALTAR,
	LIBRARY,
	TRAP_GAUNTLET,
	STATUE,
	VAULT,
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
