class_name DungeonGenerator
extends RefCounted

# Pure-data generator. Given a FloorData, produces a layout dict:
#   {
#     "cells":     Dictionary[Vector2i, int],  # tile coord -> CellType
#     "rooms":     Array[Dictionary],          # [{ type, rect, center, parent_index }]
#     "corridors": Array[Array[Vector2i]],     # each corridor = list of floor tiles
#     "bounds":    Rect2i,                     # tight bbox of all floor cells
#   }
# Caller is responsible for painting cells into a TileMapLayer and spawning
# room contents.

enum CellType { WALL, FLOOR }

# Room footprint per type (tiles). Combat rooms are deliberately the biggest
# so turn-based battles have room to spread out. Tweak in one place.
const ROOM_SIZE_BY_TYPE := {
	RoomTemplate.RoomType.ENTRY:            Vector2i(22, 16),
	RoomTemplate.RoomType.CAMPSITE:         Vector2i(18, 14),
	RoomTemplate.RoomType.CHEST:            Vector2i(14, 11),
	RoomTemplate.RoomType.MERCHANT:         Vector2i(18, 14),
	RoomTemplate.RoomType.RANDOM_ENCOUNTER: Vector2i(24, 18),
	RoomTemplate.RoomType.ENEMY:            Vector2i(32, 24),
	RoomTemplate.RoomType.MINIBOSS:         Vector2i(38, 28),
	RoomTemplate.RoomType.BOSS:             Vector2i(44, 32),
}
const ROOM_SIZE_DEFAULT := Vector2i(14, 10)

const CORRIDOR_MIN_LEN := 8
const CORRIDOR_MAX_LEN := 14
const ROOM_PADDING := 2
const PLACEMENT_ATTEMPTS := 500

# Cellular-automata pass to make rooms feel cave-like instead of rectangular.
# Initial wall chance is rolled per interior cell; the smoothing rule then
# flips a cell to WALL if >=5 of its 8 neighbors are walls. Outer 1-tile ring
# of every room, the room center, and corridor tiles are locked as FLOOR so
# the room is always traversable.
const CA_INITIAL_WALL_CHANCE := 0.42
const CA_ITERATIONS := 4

# Extras pool — the 5 types eligible for the 0-5 random extra slots.
const EXTRAS_POOL: Array[int] = [
	RoomTemplate.RoomType.CAMPSITE,
	RoomTemplate.RoomType.RANDOM_ENCOUNTER,
	RoomTemplate.RoomType.MINIBOSS,
	RoomTemplate.RoomType.ENEMY,
	RoomTemplate.RoomType.CHEST,
]

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP,
]


static func generate(floor_data: FloorData, rng_seed: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if rng_seed == 0:
		rng.randomize()
	else:
		rng.seed = rng_seed

	var queue := _build_room_queue(floor_data, rng)
	var rooms := _place_rooms(queue, floor_data, rng)
	var corridors := _connect_rooms(rooms, rng)
	var cells := _paint_cells(rooms, corridors, rng)
	return {
		"cells": cells,
		"rooms": rooms,
		"corridors": corridors,
		"bounds": _bounds_of(cells),
	}


# --- Composition --------------------------------------------------------------

static func _build_room_queue(fd: FloorData, rng: RandomNumberGenerator) -> Array[int]:
	var queue: Array[int] = []
	_repeat(queue, RoomTemplate.RoomType.ENTRY,            fd.entry_room_count)
	_repeat(queue, RoomTemplate.RoomType.CAMPSITE,         fd.campsite_room_count)
	_repeat(queue, RoomTemplate.RoomType.ENEMY,            fd.enemy_room_min)
	_repeat(queue, RoomTemplate.RoomType.MINIBOSS,         fd.miniboss_room_min)
	_repeat(queue, RoomTemplate.RoomType.RANDOM_ENCOUNTER, fd.random_encounter_min)
	_repeat(queue, RoomTemplate.RoomType.CHEST,            fd.chest_room_min)
	_repeat(queue, RoomTemplate.RoomType.MERCHANT,         fd.merchant_room_count)
	_repeat(queue, RoomTemplate.RoomType.BOSS,             fd.boss_room_count)

	var extras_count := rng.randi_range(fd.extra_room_min, fd.extra_room_max)
	for _i in extras_count:
		queue.append(EXTRAS_POOL[rng.randi_range(0, EXTRAS_POOL.size() - 1)])

	# Entry must be placed first (it's the spawn anchor). Everything else
	# shuffled so adjacency feels random.
	var entry: int = queue.pop_front()
	queue.shuffle()
	queue.push_front(entry)
	return queue


static func _repeat(arr: Array[int], value: int, count: int) -> void:
	for _i in count:
		arr.append(value)


# --- Macro placement ----------------------------------------------------------

# Placement order:
#   1. Entry anchored at origin
#   2. All non-mandatory-campsite, non-boss rooms shuffled, each with a random parent
#   3. The mandatory campsite (random parent)
#   4. The boss, with forced parent = campsite (so the only path to boss runs
#      through the rest room — boss is the last placed, nothing else can attach to it)
static func _place_rooms(queue: Array[int], _fd: FloorData, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	var remaining := queue.duplicate()

	# Pull out one entry, one mandatory campsite, and the boss for special handling.
	# Extra campsites in the extras roll stay in `remaining` and place randomly.
	remaining.erase(RoomTemplate.RoomType.ENTRY)
	var has_campsite := remaining.has(RoomTemplate.RoomType.CAMPSITE)
	if has_campsite:
		remaining.erase(RoomTemplate.RoomType.CAMPSITE)
	var has_boss := remaining.has(RoomTemplate.RoomType.BOSS)
	if has_boss:
		remaining.erase(RoomTemplate.RoomType.BOSS)

	# Entry anchored at origin.
	var entry_size := _size_for_type(RoomTemplate.RoomType.ENTRY)
	placed.append(_make_room(RoomTemplate.RoomType.ENTRY, Rect2i(-entry_size / 2, entry_size), -1))

	# Everything else (mandatory minimums minus camp/boss, plus extras) shuffled.
	remaining.shuffle()
	for room_type: int in remaining:
		_try_place(placed, room_type, rng, -1)

	# Mandatory campsite — random parent.
	var camp_index := -1
	if has_campsite:
		camp_index = _try_place(placed, RoomTemplate.RoomType.CAMPSITE, rng, -1)

	# Boss — forced adjacent to the mandatory campsite. Placed last so nothing
	# else can attach to it; the corridor through the campsite is its only entry.
	if has_boss:
		_try_place(placed, RoomTemplate.RoomType.BOSS, rng, camp_index)

	return placed


static func _try_place(placed: Array[Dictionary], room_type: int, rng: RandomNumberGenerator, forced_parent: int) -> int:
	var size := _size_for_type(room_type)
	for _attempt in PLACEMENT_ATTEMPTS:
		var parent_idx: int = forced_parent if forced_parent != -1 else rng.randi_range(0, placed.size() - 1)
		var parent_rect: Rect2i = placed[parent_idx]["rect"]
		var dir: Vector2i = DIRECTIONS[rng.randi_range(0, DIRECTIONS.size() - 1)]
		var corridor_len := rng.randi_range(CORRIDOR_MIN_LEN, CORRIDOR_MAX_LEN)
		var new_rect := _offset_rect(parent_rect, dir, corridor_len, size)
		if _overlaps_any(new_rect, placed):
			continue
		placed.append(_make_room(room_type, new_rect, parent_idx))
		return placed.size() - 1
	push_warning("DungeonGenerator: failed to place room type %d after %d attempts" % [room_type, PLACEMENT_ATTEMPTS])
	return -1


static func _size_for_type(room_type: int) -> Vector2i:
	return ROOM_SIZE_BY_TYPE.get(room_type, ROOM_SIZE_DEFAULT)


static func _offset_rect(parent: Rect2i, dir: Vector2i, gap: int, size: Vector2i) -> Rect2i:
	var pos := Vector2i.ZERO
	match dir:
		Vector2i.RIGHT:
			pos = Vector2i(parent.end.x + gap, parent.position.y + (parent.size.y - size.y) / 2)
		Vector2i.LEFT:
			pos = Vector2i(parent.position.x - gap - size.x, parent.position.y + (parent.size.y - size.y) / 2)
		Vector2i.DOWN:
			pos = Vector2i(parent.position.x + (parent.size.x - size.x) / 2, parent.end.y + gap)
		Vector2i.UP:
			pos = Vector2i(parent.position.x + (parent.size.x - size.x) / 2, parent.position.y - gap - size.y)
	return Rect2i(pos, size)


static func _overlaps_any(new_rect: Rect2i, placed: Array[Dictionary]) -> bool:
	var padded := Rect2i(
		new_rect.position - Vector2i(ROOM_PADDING, ROOM_PADDING),
		new_rect.size + Vector2i(ROOM_PADDING, ROOM_PADDING) * 2,
	)
	for room in placed:
		if padded.intersects(room["rect"]):
			return true
	return false


static func _make_room(room_type: int, rect: Rect2i, parent_index: int) -> Dictionary:
	return {
		"type": room_type,
		"rect": rect,
		"center": rect.position + rect.size / 2,
		"parent_index": parent_index,
	}


# --- Corridors ---------------------------------------------------------------

static func _connect_rooms(rooms: Array[Dictionary], _rng: RandomNumberGenerator) -> Array[Array]:
	var corridors: Array[Array] = []
	for room in rooms:
		var pi: int = room["parent_index"]
		if pi == -1:
			continue
		corridors.append(_l_corridor(rooms[pi]["center"], room["center"]))
	return corridors


static func _l_corridor(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	# L-shaped corridor, 2 tiles wide. Goes horizontal first, then vertical.
	# Each step appends the path tile + a perpendicular neighbor so the
	# corridor is 2 wide and the player isn't squeezing through 1-tile gaps.
	var tiles: Array[Vector2i] = []
	var x := from.x
	var y := from.y
	var step_x: int = signi(to.x - from.x)
	var step_y: int = signi(to.y - from.y)
	while x != to.x:
		tiles.append(Vector2i(x, y))
		tiles.append(Vector2i(x, y + 1))
		x += step_x
	while y != to.y:
		tiles.append(Vector2i(x, y))
		tiles.append(Vector2i(x + 1, y))
		y += step_y
	tiles.append(Vector2i(x, y))
	tiles.append(Vector2i(x + 1, y))
	tiles.append(Vector2i(x, y + 1))
	tiles.append(Vector2i(x + 1, y + 1))
	return tiles


# --- Cell painting -----------------------------------------------------------

static func _paint_cells(rooms: Array[Dictionary], corridors: Array[Array], rng: RandomNumberGenerator) -> Dictionary:
	var cells: Dictionary = {}
	var corridor_set: Dictionary = {}  # used as a set: keys are Vector2i corridor tiles

	# Step 1: room interiors as floor.
	for room in rooms:
		var rect: Rect2i = room["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				cells[Vector2i(x, y)] = CellType.FLOOR

	# Step 2: corridors as floor (and tracked for CA locking).
	for corridor: Array in corridors:
		for tile: Vector2i in corridor:
			cells[tile] = CellType.FLOOR
			corridor_set[tile] = true

	# Step 3: cellular-automata pass per room for cave-like interiors.
	for room in rooms:
		_cavify_room(cells, room, corridor_set, rng)

	# Step 4: paint walls around every remaining floor cell.
	var floors: Array = cells.keys()
	for tile: Vector2i in floors:
		if cells[tile] != CellType.FLOOR:
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor: Vector2i = tile + Vector2i(dx, dy)
				if not cells.has(neighbor):
					cells[neighbor] = CellType.WALL

	return cells


# Run CA over a room's full rect (including the boundary cells) so the room
# outline itself becomes irregular, not just the interior. Corridor tiles and
# the room center are locked as FLOOR so the corridor entry → center path is
# always traversable.
static func _cavify_room(cells: Dictionary, room: Dictionary, corridor_set: Dictionary, rng: RandomNumberGenerator) -> void:
	var rect: Rect2i = room["rect"]
	var center: Vector2i = room["center"]
	if rect.size.x < 4 or rect.size.y < 4:
		return  # too small to cavify; leave as rectangle

	var interior: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			interior.append(Vector2i(x, y))

	# Randomize (skipping locked tiles).
	for t: Vector2i in interior:
		if corridor_set.has(t) or t == center:
			cells[t] = CellType.FLOOR
			continue
		cells[t] = CellType.WALL if rng.randf() < CA_INITIAL_WALL_CHANCE else CellType.FLOOR

	# Smooth.
	for _i in CA_ITERATIONS:
		var next: Dictionary = {}
		for t: Vector2i in interior:
			if corridor_set.has(t) or t == center:
				next[t] = CellType.FLOOR
				continue
			var walls := 0
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var n: Vector2i = t + Vector2i(dx, dy)
					if cells.get(n, CellType.WALL) == CellType.WALL:
						walls += 1
			next[t] = CellType.WALL if walls >= 5 else CellType.FLOOR
		for t: Vector2i in next:
			cells[t] = next[t]


static func _bounds_of(cells: Dictionary) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var first: Vector2i = cells.keys()[0]
	var min_p := first
	var max_p := first
	for tile: Vector2i in cells.keys():
		min_p.x = mini(min_p.x, tile.x)
		min_p.y = mini(min_p.y, tile.y)
		max_p.x = maxi(max_p.x, tile.x)
		max_p.y = maxi(max_p.y, tile.y)
	return Rect2i(min_p, max_p - min_p + Vector2i.ONE)
