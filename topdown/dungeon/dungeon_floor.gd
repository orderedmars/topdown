extends Node2D

# Dungeon-floor scene controller. Generates a floor at _ready, paints it to
# the TileMapLayer, builds wall collision, and places the player at the entry
# room. Reads `FloorData` from `floor_data` (or falls back to defaults).

const TILE_PX := 32

# How many tiles before the room edge to pre-reveal a room. Lets the player
# peek into the next room from the approach corridor instead of stepping in
# blind. Only counts when the player is in a corridor that connects to the
# room, so we don't reveal through unrelated walls.
const REVEAL_BUFFER := 3

# Block-out colors used until real tile art exists. Swap to TileMapLayer
# painting once a tileset with valid textures is plugged into the scene.
const FLOOR_COLOR := Color(0.4, 0.34, 0.28)
const WALL_COLOR := Color(0.12, 0.12, 0.16)

@export var floor_data: FloorData
@export var rng_seed: int = 0  # 0 = random per run

@export_group("Debug")
@export var show_room_labels: bool = true

@onready var wall_body: StaticBody2D = $WallBody
@onready var markers: Node2D = $Markers

var _data: FloorData = null
var _cells: Dictionary = {}
var _rooms: Array = []
var _cell_room: Dictionary = {}             # Vector2i tile -> room index
var _cell_corridor: Dictionary = {}         # Vector2i tile -> corridor index (only when not in any room)
var _corridor_endpoints: Array[Vector2i] = []  # corridor idx -> Vector2i(room_a, room_b)
var _visible_rooms: Dictionary = {}         # room idx -> true; used as a set
var _room_labels: Dictionary = {}           # room idx -> Label
var _room_entry_portals: Dictionary = {}    # room idx -> MagicCirclePortal


func _ready() -> void:
	_data = floor_data if floor_data != null else _default_floor_data()
	var layout := DungeonGenerator.generate(_data, rng_seed)
	_cells = layout["cells"]
	_rooms = layout["rooms"]
	_build_cell_room_map()
	_build_corridor_maps(layout["corridors"])
	_carve_portal_strips(_rooms)
	_build_wall_collision(_cells)
	_build_navigation_region(_cells)
	_spawn_room_markers(_rooms)
	_spawn_entry_portals(_rooms)
	_position_player(_rooms)
	# Reveal the entry room so the player can see where they're standing.
	# Other rooms unveil as the player steps into them.
	_mark_room_visible(_room_index_of_type(RoomTemplate.RoomType.ENTRY))
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _visible_rooms.size() == _rooms.size():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var tile := Vector2i(int(floor(player.global_position.x / TILE_PX)), int(floor(player.global_position.y / TILE_PX)))
	# Which room (if any) the player's current corridor leads to. Used to gate
	# pre-reveal so the buffer only triggers along the approach path, not
	# through walls toward an unrelated room that happens to be nearby.
	var corridor_rooms := Vector2i(-1, -1)
	if _cell_corridor.has(tile):
		corridor_rooms = _corridor_endpoints[_cell_corridor[tile]]
	for i in _rooms.size():
		if _visible_rooms.has(i):
			continue
		var rect: Rect2i = _rooms[i]["rect"]
		if rect.has_point(tile):
			_mark_room_visible(i)
			continue
		var buffered := Rect2i(
			rect.position - Vector2i(REVEAL_BUFFER, REVEAL_BUFFER),
			rect.size + Vector2i(REVEAL_BUFFER, REVEAL_BUFFER) * 2,
		)
		if not buffered.has_point(tile):
			continue
		if corridor_rooms.x == i or corridor_rooms.y == i:
			_mark_room_visible(i)


func _mark_room_visible(idx: int) -> void:
	if idx < 0 or _visible_rooms.has(idx):
		return
	_visible_rooms[idx] = true
	if _room_labels.has(idx):
		_room_labels[idx].visible = true
	if _room_entry_portals.has(idx):
		_room_entry_portals[idx].visible = true
	# Combat content is spawned on reveal (not at floor gen) so hearing-cone
	# areas don't react through walls and a fast player can't bump invisible
	# enemies before the room is lit.
	var room_type: int = int(_rooms[idx]["type"])
	match room_type:
		RoomTemplate.RoomType.BOSS:
			_spawn_boss(_rooms[idx])
		RoomTemplate.RoomType.ENEMY:
			_spawn_room_enemies(_rooms[idx], _data.enemy_pool, _data.enemies_per_room_min, _data.enemies_per_room_max)
		RoomTemplate.RoomType.MINIBOSS:
			_spawn_room_enemies(_rooms[idx], _data.miniboss_pool, _data.minibosses_per_room_min, _data.minibosses_per_room_max)
	queue_redraw()


# Map every cell to its room (expanded by 1 so the room's wall ring is included).
# Cells outside any expanded rect fall through to the corridor map.
func _build_cell_room_map() -> void:
	_cell_room.clear()
	for i in _rooms.size():
		var rect: Rect2i = _rooms[i]["rect"]
		var expanded := Rect2i(rect.position - Vector2i.ONE, rect.size + Vector2i(2, 2))
		for x in range(expanded.position.x, expanded.end.x):
			for y in range(expanded.position.y, expanded.end.y):
				var t := Vector2i(x, y)
				if not _cell_room.has(t):
					_cell_room[t] = i


# Map corridor cells (and their wall ring) to a corridor index. Corridor k
# connects two rooms; track the endpoints so we can show the corridor when
# either room is visible. The generator emits one corridor per non-entry room,
# in room order, so we can derive endpoints by replaying that iteration.
func _build_corridor_maps(corridors: Array) -> void:
	_cell_corridor.clear()
	_corridor_endpoints.clear()
	var k := 0
	for i in _rooms.size():
		var pi: int = _rooms[i]["parent_index"]
		if pi == -1:
			continue
		_corridor_endpoints.append(Vector2i(pi, i))
		for tile in corridors[k]:
			var t: Vector2i = tile
			if _cell_room.has(t):
				continue
			_cell_corridor[t] = k
			# Map the 1-tile ring (the corridor's walls) so they hide with it.
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var n: Vector2i = t + Vector2i(dx, dy)
					if _cell_room.has(n) or _cell_corridor.has(n):
						continue
					_cell_corridor[n] = k
		k += 1


func _is_cell_visible(tile: Vector2i) -> bool:
	if _cell_room.has(tile):
		return _visible_rooms.has(_cell_room[tile])
	if _cell_corridor.has(tile):
		var pair: Vector2i = _corridor_endpoints[_cell_corridor[tile]]
		return _visible_rooms.has(pair.x) or _visible_rooms.has(pair.y)
	return false


func _room_index_of_type(room_type: int) -> int:
	for i in _rooms.size():
		if int(_rooms[i]["type"]) == room_type:
			return i
	return -1


# Force a 5x3 floor strip from each entry/boss room's center to center+(4,0).
# The portal spawns at center+(3,0); this guarantees CA can't wall it off and
# the player has a clear walk from spawn (or boss kill spot) to the portal.
func _carve_portal_strips(rooms: Array) -> void:
	for room: Dictionary in rooms:
		var t: int = room["type"]
		if t != RoomTemplate.RoomType.ENTRY and t != RoomTemplate.RoomType.BOSS:
			continue
		var c: Vector2i = room["center"]
		for x in range(5):
			for y in range(-1, 2):
				_cells[c + Vector2i(x, y)] = DungeonGenerator.CellType.FLOOR


func _draw() -> void:
	var tile_size := Vector2(TILE_PX, TILE_PX)
	for tile: Vector2i in _cells.keys():
		if not _is_cell_visible(tile):
			continue
		var color: Color = FLOOR_COLOR if _cells[tile] == DungeonGenerator.CellType.FLOOR else WALL_COLOR
		draw_rect(Rect2(Vector2(tile.x, tile.y) * TILE_PX, tile_size), color)


func _build_wall_collision(cells: Dictionary) -> void:
	for child in wall_body.get_children():
		child.queue_free()

	# Greedy horizontal merge: each row, walk left-to-right and emit one
	# rectangle per contiguous wall run. Cuts shape count ~5x vs per-tile.
	var bounds := _grid_bounds(cells)
	for y in range(bounds.position.y, bounds.end.y):
		var run_start := -2147483648
		for x in range(bounds.position.x, bounds.end.x + 1):
			var is_wall: bool = cells.get(Vector2i(x, y), -1) == DungeonGenerator.CellType.WALL
			if is_wall and run_start == -2147483648:
				run_start = x
			elif not is_wall and run_start != -2147483648:
				_add_wall_rect(run_start, y, x - run_start)
				run_start = -2147483648


func _add_wall_rect(start_x: int, y: int, length: int) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length * TILE_PX, TILE_PX)
	shape.shape = rect
	shape.position = Vector2((start_x + length / 2.0) * TILE_PX, (y + 0.5) * TILE_PX)
	wall_body.add_child(shape)


# Bake a NavigationPolygon so enemies route around corners/walls instead of
# pressing straight into them. Each FLOOR cell contributes a 1-tile square as
# traversable source geometry; the baker merges them into a single polygon
# (with holes for any CA-carved interior walls). `agent_radius` insets paths
# off wall edges so the 32px enemy box doesn't clip while pathing through
# 64px corridors.
func _build_navigation_region(cells: Dictionary) -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 8.0
	var source_data := NavigationMeshSourceGeometryData2D.new()
	for key in cells.keys():
		var t: Vector2i = key
		if cells[t] != DungeonGenerator.CellType.FLOOR:
			continue
		source_data.add_traversable_outline(PackedVector2Array([
			Vector2(t.x, t.y) * TILE_PX,
			Vector2(t.x + 1, t.y) * TILE_PX,
			Vector2(t.x + 1, t.y + 1) * TILE_PX,
			Vector2(t.x, t.y + 1) * TILE_PX,
		]))
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_data)
	var region := NavigationRegion2D.new()
	region.navigation_polygon = nav_poly
	add_child(region)


# --- Spawning ----------------------------------------------------------------

func _spawn_room_markers(rooms: Array) -> void:
	for child in markers.get_children():
		child.queue_free()
	_room_labels.clear()
	if not show_room_labels:
		return
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var label := Label.new()
		label.text = _room_type_name(room["type"])
		label.position = Vector2(room["center"]) * TILE_PX - Vector2(40, 8)
		label.add_theme_color_override("font_color", _room_type_color(room["type"]))
		label.visible = false
		markers.add_child(label)
		_room_labels[i] = label


func _position_player(rooms: Array) -> void:
	var entry_room := _find_room(rooms, RoomTemplate.RoomType.ENTRY)
	if entry_room.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.global_position = Vector2(entry_room["center"]) * TILE_PX + Vector2(TILE_PX, TILE_PX) * 0.5


func _spawn_entry_portals(rooms: Array) -> void:
	_room_entry_portals.clear()
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		if int(room["type"]) != RoomTemplate.RoomType.ENTRY:
			continue
		var tile: Vector2i = room["center"] + Vector2i(3, 0)
		var portal := MagicCirclePortal.new()
		portal.ring_color = Color(0.95, 0.85, 0.4)
		portal.activated.connect(_return_to_town)
		portal.position = Vector2(tile) * TILE_PX + Vector2(TILE_PX, TILE_PX) * 0.5
		portal.visible = false
		add_child(portal)
		_room_entry_portals[i] = portal


func _spawn_boss(room: Dictionary) -> void:
	var boss := BossPlaceholder.new()
	boss.position = Vector2(room["center"]) * TILE_PX + Vector2(TILE_PX, TILE_PX) * 0.5
	boss.defeated.connect(_on_boss_defeated.bind(room))
	add_child(boss)


# Spawn `count` enemies picked from `pool` onto random FLOOR tiles inside the
# room rect. Silently skips if the pool is empty (e.g. miniboss_pool unset).
func _spawn_room_enemies(room: Dictionary, pool: Array[PackedScene], count_min: int, count_max: int) -> void:
	if pool.is_empty() or count_max <= 0:
		return
	var count := randi_range(count_min, count_max)
	if count <= 0:
		return
	var tiles := _pick_floor_tiles_in_room(room, count)
	for tile: Vector2i in tiles:
		var scene: PackedScene = pool[randi() % pool.size()]
		var enemy: Node2D = scene.instantiate()
		enemy.position = Vector2(tile) * TILE_PX + Vector2(TILE_PX, TILE_PX) * 0.5
		add_child(enemy)


# Returns up to `count` FLOOR tiles inside the room, each at least 3 tiles from
# any previously picked tile so enemies don't pile up. Excludes the room center
# (corridor entry point) so the player isn't bumped on first step in.
func _pick_floor_tiles_in_room(room: Dictionary, count: int) -> Array[Vector2i]:
	var rect: Rect2i = room["rect"]
	var center: Vector2i = room["center"]
	var candidates: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var t := Vector2i(x, y)
			if t == center:
				continue
			if _cells.get(t, DungeonGenerator.CellType.WALL) != DungeonGenerator.CellType.FLOOR:
				continue
			candidates.append(t)
	candidates.shuffle()
	var picked: Array[Vector2i] = []
	const MIN_DIST_SQ := 9  # 3 tiles
	for t: Vector2i in candidates:
		var too_close := false
		for p: Vector2i in picked:
			if (t - p).length_squared() < MIN_DIST_SQ:
				too_close = true
				break
		if too_close:
			continue
		picked.append(t)
		if picked.size() >= count:
			break
	return picked


func _on_boss_defeated(room: Dictionary) -> void:
	var tile: Vector2i = room["center"] + Vector2i(3, 0)
	var portal := MagicCirclePortal.new()
	portal.ring_color = Color(0.7, 0.45, 1.0)
	portal.activated.connect(_descend_floor)
	portal.position = Vector2(tile) * TILE_PX + Vector2(TILE_PX, TILE_PX) * 0.5
	add_child(portal)


func _return_to_town() -> void:
	RunState.exit_dungeon()
	get_tree().change_scene_to_file("res://scenes/town.tscn")


func _descend_floor() -> void:
	RunState.enter_floor(RunState.current_floor + 1)
	get_tree().reload_current_scene()


# --- Helpers -----------------------------------------------------------------

func _find_room(rooms: Array, room_type: int) -> Dictionary:
	for room in rooms:
		if room["type"] == room_type:
			return room
	return {}


func _grid_bounds(cells: Dictionary) -> Rect2i:
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


func _room_type_name(t: int) -> String:
	match t:
		RoomTemplate.RoomType.ENTRY:            return "ENTRY"
		RoomTemplate.RoomType.CAMPSITE:         return "CAMPSITE"
		RoomTemplate.RoomType.ENEMY:            return "ENEMY"
		RoomTemplate.RoomType.MINIBOSS:         return "MINIBOSS"
		RoomTemplate.RoomType.RANDOM_ENCOUNTER: return "ENCOUNTER"
		RoomTemplate.RoomType.CHEST:            return "CHEST"
		RoomTemplate.RoomType.MERCHANT:         return "MERCHANT"
		RoomTemplate.RoomType.BOSS:             return "BOSS"
		_: return "?"


func _room_type_color(t: int) -> Color:
	match t:
		RoomTemplate.RoomType.ENTRY:            return Color(0.6, 0.9, 1.0)
		RoomTemplate.RoomType.CAMPSITE:         return Color(1.0, 0.7, 0.4)
		RoomTemplate.RoomType.ENEMY:            return Color(1.0, 0.5, 0.5)
		RoomTemplate.RoomType.MINIBOSS:         return Color(1.0, 0.3, 0.3)
		RoomTemplate.RoomType.RANDOM_ENCOUNTER: return Color(0.8, 0.6, 1.0)
		RoomTemplate.RoomType.CHEST:            return Color(1.0, 0.9, 0.3)
		RoomTemplate.RoomType.MERCHANT:         return Color(0.5, 1.0, 0.7)
		RoomTemplate.RoomType.BOSS:             return Color(1.0, 0.1, 0.1)
		_: return Color.WHITE


func _default_floor_data() -> FloorData:
	# Try res://dungeon/floors/floor_<N>.tres first so RunState.current_floor
	# drives which floor's content loads on scene reload. Fall back to a blank
	# resource so the scene still boots if the .tres is missing.
	var n: int = maxi(1, RunState.current_floor)
	var path: String = "res://dungeon/floors/floor_%d.tres" % n
	if ResourceLoader.exists(path):
		var loaded: FloorData = ResourceLoader.load(path) as FloorData
		if loaded != null:
			return loaded
	var fd := FloorData.new()
	fd.floor_number = n
	return fd
