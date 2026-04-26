extends CharacterBody2D

signal stats_changed(health, mana, stamina)

enum SkillMode { NONE, FIREBALL, ARROW }
var current_skill_mode: SkillMode = SkillMode.NONE

@export_group("Movement Speeds")
@export var walk_speed: float = 200.0
@export var sprint_speed: float = 350.0
@export var crouch_speed: float = 100.0

@export_group("Stats")
@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var max_stamina: float = 100.0
@export var base_detection_radius: float = 120.0

var health: float
var mana: float
var stamina: float

var current_speed: float = 200.0
var is_crouching: bool = false
var is_sprinting: bool = false

# Status Effects
var is_stunned: bool = false
var slow_multiplier: float = 1.0
var stun_timer: float = 0.0

@onready var sprite: ColorRect = $Sprite
@onready var detection_shape: CollisionShape2D = $DetectionZone/CollisionShape2D
@onready var detection_visual: Polygon2D = $DetectionZone/DetectionVisual

# Projectiles
const FIREBALL_SCENE = preload("res://skills/fireball.tscn")
const ARROW_SCENE = preload("res://skills/arrow.tscn")

var can_cast: bool = false # Controlled by hover/range

func _ready() -> void:
	health = max_health; mana = max_mana; stamina = max_stamina
	add_to_group("player")
	detection_visual.color = Color(0.2, 0.4, 1.0, 0.05)
	
	collision_layer = 2
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if is_stunned:
		stun_timer -= delta; velocity = Vector2.ZERO
		if stun_timer <= 0: is_stunned = false
	else:
		handle_movement_state(delta)
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var direction = Vector2.ZERO
		if abs(input_dir.x) > abs(input_dir.y): direction.x = sign(input_dir.x)
		elif abs(input_dir.y) > 0: direction.y = sign(input_dir.y)
		velocity = direction * current_speed * slow_multiplier
	
	move_and_slide()
	update_detection_radius()
	update_targeting_logic()
	stats_changed.emit(health, mana, stamina)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_skill_mode != SkillMode.NONE and can_cast:
				cast_active_skill(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			current_skill_mode = SkillMode.NONE

func update_targeting_logic():
	# Reset all enemy highlights
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies: e.is_highlighted = false
	can_cast = false
	
	if current_skill_mode == SkillMode.NONE: return
	
	var mouse_pos = get_global_mouse_position()
	
	if current_skill_mode == SkillMode.FIREBALL:
		# Highlight all enemies in blast radius (60 pixels)
		for e in enemies:
			if e.global_position.distance_to(mouse_pos) < 60.0:
				e.is_highlighted = true
				can_cast = true # Can fire if at least one target is in range
	
	elif current_skill_mode == SkillMode.ARROW:
		# Highlight only the enemy directly under the mouse
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = mouse_pos
		query.collision_mask = 2 # Entities layer
		var results = space_state.intersect_point(query)
		for res in results:
			var collider = res.collider
			if collider.is_in_group("enemy"):
				collider.is_highlighted = true
				can_cast = true
				break

func handle_movement_state(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch")
	if is_crouching:
		current_speed = crouch_speed; sprite.color = Color("#111155"); is_sprinting = false
	else:
		sprite.color = Color("#3344ff")
		var moving = velocity.length() > 0
		if Input.is_action_pressed("sprint") and stamina > 0 and moving:
			is_sprinting = true; current_speed = sprint_speed; stamina -= 25.0 * delta
		else:
			is_sprinting = false; current_speed = walk_speed; stamina = min(stamina + 15.0 * delta, max_stamina)

func update_detection_radius() -> void:
	var target_radius = base_detection_radius
	if is_crouching: target_radius *= 0.5
	if detection_shape.shape: detection_shape.shape.radius = target_radius
	var points = PackedVector2Array([Vector2.ZERO])
	var ray_count = 32
	var space_state = get_world_2d().direct_space_state
	for i in range(ray_count + 1):
		var angle = (i * 2 * PI) / ray_count
		var ray_direction = Vector2(cos(angle), sin(angle))
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + ray_direction * target_radius)
		query.exclude = [self.get_rid()]
		query.collision_mask = 1 # Only hit world
		var result = space_state.intersect_ray(query)
		points.append(to_local(result.position) if result else ray_direction * target_radius)
	detection_visual.polygon = points

func set_skill_mode(mode: SkillMode): current_skill_mode = mode

func cast_active_skill(target_pos: Vector2):
	if current_skill_mode == SkillMode.FIREBALL:
		if mana >= 15.0:
			mana -= 15.0
			var fb = FIREBALL_SCENE.instantiate()
			# Adding to world root so it isn't affected by player movement/rotation
			get_tree().current_scene.add_child(fb)
			fb.global_position = global_position
			fb.target_pos = target_pos
			current_skill_mode = SkillMode.NONE
	elif current_skill_mode == SkillMode.ARROW:
		if stamina >= 10.0:
			stamina -= 10.0
			var arrow = ARROW_SCENE.instantiate()
			get_tree().current_scene.add_child(arrow)
			arrow.global_position = global_position
			arrow.direction = (target_pos - global_position).normalized()
			arrow.rotation = arrow.direction.angle()
			current_skill_mode = SkillMode.NONE

func heal(amount: float):
	health = min(health + amount, max_health); mana = max_mana; stamina = max_stamina
	stats_changed.emit(health, mana, stamina)

func apply_trap_damage(amount: float): health = max(0, health - amount)
func apply_slow(multiplier: float): if not is_crouching: slow_multiplier = multiplier; is_sprinting = false
func clear_slow(): slow_multiplier = 1.0
func apply_stun(duration: float): if not is_crouching: is_stunned = true; stun_timer = duration; is_sprinting = false
