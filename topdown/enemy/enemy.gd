extends CharacterBody2D

enum State { IDLE, SUSPICIOUS, CHASING, SEARCHING }
var current_state: State = State.IDLE

@export var speed: float = 140.0
@export var suspicion_time: float = 1.5   # seconds of continuous hearing before full chase
@export var chase_timeout: float = 5.0    # seconds to rush last known pos after losing detection
@export var search_wait_time: float = 3.0 # seconds to scan at last known pos before giving up
@export var loot_table: LootTable = null  # assign in Inspector or leave null for no drops

# Vision and hearing geometry is set via the CollisionShapes in the Inspector:
#   VisionCone/CollisionShape2D  → ConvexPolygonShape2D  (forward triangle)
#   DetectionZone/CollisionShape2D → CircleShape2D       (hearing radius)
# The player's DetectionZone radius (layer 4) grows when sprinting, shrinks when crouching.
# Overlap between the player's noise radius and these zones triggers detection.

var health: float = 50.0
var target: Node2D = null
var last_known_position: Vector2
var state_timer: float = 0.0
var suspicion_timer: float = 0.0
var is_highlighted: bool = false

const SCAN_SPEED: float = 0.5 # radians/sec — how fast the enemy sweeps its vision cone when idle

@onready var vision_visual: Polygon2D = $VisionCone/VisionVisual
@onready var hearing_visual: Polygon2D = $DetectionZone/HearingVisual
@onready var vision_cone: Area2D = $VisionCone
@onready var hearing_zone: Area2D = $DetectionZone
@onready var outline: ReferenceRect = $Outline
@onready var health_bar: ProgressBar = $HealthBarContainer/ProgressBar
@onready var alert_label: Label = $AlertLabel

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 1
	health_bar.max_value = 50.0
	health_bar.value = health
	alert_label.hide()
	last_known_position = global_position
	vision_visual.color = Color(1, 1, 0, 0.12)
	hearing_visual.color = Color(1, 0, 0, 0.05)

func _physics_process(delta: float) -> void:
	outline.visible = is_highlighted

	match current_state:
		State.IDLE:
			alert_label.hide()
			velocity = Vector2.ZERO
			# Sweep the vision cone left and right so it has a purpose when idle.
			# sin() makes it oscillate naturally without a hard reversal.
			state_timer += delta
			rotation += SCAN_SPEED * sin(state_timer * 1.2) * delta

			if check_vision():
				start_chase()
			elif check_hearing():
				start_suspicion()

		State.SUSPICIOUS:
			alert_label.show()
			alert_label.text = "?"
			alert_label.modulate = Color.YELLOW
			velocity = Vector2.ZERO
			# Turn toward the source of the sound while building suspicion.
			if target:
				var angle_to = (target.global_position - global_position).angle()
				rotation = lerp_angle(rotation, angle_to, 3.0 * delta)

			if check_vision():
				# Saw them — no need to wait, chase immediately.
				start_chase()
			elif check_hearing():
				suspicion_timer += delta
				if suspicion_timer >= suspicion_time:
					start_chase()
			else:
				# Lost the sound — cool down slowly.
				suspicion_timer -= delta * 0.5
				if suspicion_timer <= 0.0:
					current_state = State.IDLE

		State.CHASING:
			alert_label.show()
			alert_label.text = "!"
			alert_label.modulate = Color.RED

			if check_vision() or check_hearing():
				# Player still detected — update memory and pursue directly.
				last_known_position = target.global_position
				state_timer = chase_timeout
				var dir = (target.global_position - global_position).normalized()
				velocity = dir * speed
				rotation = lerp_angle(rotation, dir.angle(), 10.0 * delta)
			else:
				# Lost detection — rush to last known position.
				state_timer -= delta
				if state_timer <= 0.0:
					start_searching()
				else:
					var dir = (last_known_position - global_position).normalized()
					velocity = dir * speed * 0.8
					rotation = lerp_angle(rotation, dir.angle(), 5.0 * delta)

		State.SEARCHING:
			# Enemy arrived at last known position and is scanning for the player.
			alert_label.show()
			alert_label.text = "?"
			alert_label.modulate = Color.ORANGE

			if check_vision() or check_hearing():
				start_chase()
				return

			var dist = global_position.distance_to(last_known_position)
			if dist > 15.0:
				# Still travelling to last known position.
				var dir = (last_known_position - global_position).normalized()
				velocity = dir * speed * 0.6
				rotation = lerp_angle(rotation, dir.angle(), 3.0 * delta)
			else:
				# Arrived — sweep and wait before giving up.
				velocity = Vector2.ZERO
				state_timer -= delta
				rotation += SCAN_SPEED * 1.5 * sin(state_timer * 2.0) * delta
				if state_timer <= 0.0:
					current_state = State.IDLE

	move_and_slide()
	update_visual_polygons()

# --- Detection helpers ---

func check_vision() -> bool:
	for area in vision_cone.get_overlapping_areas():
		if not area.is_in_group("player_detection"):
			continue
		var player = area.get_parent()
		# Line-of-sight raycast — walls (layer 1) block vision.
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
		query.collision_mask = 1
		if not space_state.intersect_ray(query):
			target = player
			return true
	return false

func check_hearing() -> bool:
	for area in hearing_zone.get_overlapping_areas():
		if area.is_in_group("player_detection"):
			target = area.get_parent()
			return true
	return false

# --- State transitions ---

func start_suspicion():
	current_state = State.SUSPICIOUS
	suspicion_timer = 0.0

func start_chase():
	current_state = State.CHASING
	state_timer = chase_timeout
	if target:
		last_known_position = target.global_position

func start_searching():
	current_state = State.SEARCHING
	state_timer = search_wait_time
	velocity = Vector2.ZERO

# --- Damage ---

func take_damage(amt: float):
	health -= amt
	health_bar.value = health
	var player = get_tree().get_first_node_in_group("player")
	if player:
		target = player
		start_chase()
	if health <= 0:
		_spawn_loot.call_deferred()
		queue_free()

func apply_trap_damage(amt: float):
	take_damage(amt)

func _spawn_loot() -> void:
	if loot_table == null:
		return
	var drops = loot_table.roll()

	# Auto-pick items scatter directly onto the floor.
	const PICKUP_SCENE = preload("res://world/item_pickup.tscn")
	for entry in drops["auto"]:
		var pickup = PICKUP_SCENE.instantiate()
		get_tree().current_scene.add_child(pickup)
		pickup.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		pickup.item = entry["item"]
		pickup.quantity = entry["quantity"]

	# Container drops go into a single loot bag at the enemy's position.
	if not drops["container"].is_empty():
		const CONTAINER_SCENE = preload("res://world/loot_container.tscn")
		var container = CONTAINER_SCENE.instantiate()
		get_tree().current_scene.add_child(container)
		container.global_position = global_position
		container.setup(drops["container"])

# --- Visuals ---

func update_visual_polygons():
	var cone_shape = $VisionCone/CollisionShape2D.shape
	if cone_shape is ConvexPolygonShape2D:
		vision_visual.polygon = cone_shape.points

	var circle_shape = $DetectionZone/CollisionShape2D.shape
	if circle_shape is CircleShape2D:
		hearing_visual.polygon = get_circle_points(circle_shape.radius)

func get_circle_points(r: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(24):
		var a = i * PI * 2.0 / 24.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
