extends CharacterBody2D

@export var speed: float = 120.0
@export var max_health: float = 50.0
@export var chase_timeout: float = 3.0

var health: float
var target: Node2D = null
var is_chasing: bool = false
var slow_multiplier: float = 1.0
var stun_timer: float = 0.0
var is_stunned: bool = false

var search_timer: float = 0.0
var is_highlighted: bool = false

@onready var health_bar: ProgressBar = $HealthBarContainer/ProgressBar
@onready var raycast: RayCast2D = $RayCast2D
@onready var hearing_visual: Polygon2D = $DetectionZone/HearingVisual
@onready var vision_visual: Polygon2D = $VisionCone/VisionVisual
@onready var outline: ReferenceRect = $Outline

func _ready() -> void:
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	add_to_group("enemy")
	hearing_visual.color = Color(1, 0, 0, 0.05)
	vision_visual.color = Color(1, 0.5, 0, 0.08)
	
	# Projectiles should only hit these layers
	collision_layer = 2 # Entities
	collision_mask = 1 # World

func _physics_process(delta: float) -> void:
	update_visuals()
	outline.visible = is_highlighted
	
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0: is_stunned = false
		return

	var currently_detects = check_for_player_radius()

	if is_chasing:
		if currently_detects:
			search_timer = chase_timeout
			move_towards_player()
		else:
			search_timer -= delta
			if search_timer <= 0:
				is_chasing = false
				target = null
			else:
				move_towards_player()

func move_towards_player():
	if not target: return
	var diff = target.global_position - global_position
	var direction = Vector2.ZERO
	if abs(diff.x) > abs(diff.y): direction.x = sign(diff.x)
	else: direction.y = sign(diff.y)
	velocity = direction * speed * slow_multiplier
	if direction.x > 0: rotation = 0
	elif direction.x < 0: rotation = PI
	elif direction.y > 0: rotation = PI/2
	elif direction.y < 0: rotation = -PI/2
	move_and_slide()

func update_visuals():
	hearing_visual.polygon = get_visible_polygon(150.0, 0, 2 * PI)
	vision_visual.polygon = get_visible_polygon(250.0, -deg_to_rad(30), deg_to_rad(30))

func get_visible_polygon(radius: float, start_angle: float, end_angle: float) -> PackedVector2Array:
	var points = PackedVector2Array([Vector2.ZERO])
	var ray_count = 24
	var space_state = get_world_2d().direct_space_state
	for i in range(ray_count + 1):
		var angle = lerp(start_angle, end_angle, float(i) / ray_count)
		var global_ray_dir = Vector2(cos(angle), sin(angle)).rotated(global_rotation)
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + global_ray_dir * radius)
		query.exclude = [self.get_rid()]
		query.collision_mask = 1 # Only hit world
		var result = space_state.intersect_ray(query)
		points.append(to_local(result.position) if result else Vector2(cos(angle), sin(angle)) * radius)
	return points

func check_for_player_radius() -> bool:
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node: return false
	var detected = false
	var hearing_overlaps = $DetectionZone.get_overlapping_areas()
	var vision_overlaps = $VisionCone.get_overlapping_areas()
	for area in hearing_overlaps + vision_overlaps:
		if area.is_in_group("player_detection"):
			var to_player = player_node.global_position - global_position
			raycast.target_position = to_local(player_node.global_position)
			raycast.force_raycast_update()
			if not raycast.is_colliding() or raycast.get_collider() == player_node:
				if area in vision_overlaps:
					# Vision cone angle check (60 degrees total)
					var angle_to_player = abs(Vector2(1, 0).rotated(global_rotation).angle_to(to_player))
					if angle_to_player <= deg_to_rad(30):
						detected = true
						break
				elif not player_node.is_crouching:
					detected = true
					break
	if detected:
		target = player_node
		is_chasing = true
	return detected

func take_damage(amount: float) -> void:
	health -= amount
	health_bar.value = health
	var player = get_tree().get_first_node_in_group("player")
	if player:
		target = player
		is_chasing = true
		search_timer = chase_timeout
	if health <= 0: health = max_health; health_bar.value = health

func apply_trap_damage(amount: float): take_damage(amount)
func apply_slow(multiplier: float): slow_multiplier = multiplier
func clear_slow(): slow_multiplier = 1.0
func apply_stun(duration: float):
	is_stunned = true
	stun_timer = duration
	velocity = Vector2.ZERO
