extends CharacterBody2D

signal stats_changed(health, mana, stamina)


enum SkillMode { NONE, FIREBALL, ARROW }
var current_skill_mode: SkillMode = SkillMode.NONE

@export_group("Movement Speeds")
@export var walk_speed: float = 200.0
@export var sprint_speed: float = 350.0
@export var crouch_speed: float = 120.0

@export_group("Stats")
@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var max_stamina: float = 100.0
var health: float; var mana: float; var stamina: float

# Projectiles
const FIREBALL_SCENE = preload("res://skills/fireball.tscn")
const ARROW_SCENE = preload("res://skills/arrow.tscn")

# Trail for followers
var position_history: Array[Dictionary] = []

@export var base_detection_radius: float = 120.0

var is_sprinting: bool = false
var is_crouching: bool = false
var is_stunned: bool = false
var stun_timer: float = 0.0
var slow_multiplier: float = 1.0
var can_cast: bool = false

@onready var sprite: ColorRect = $Sprite
@onready var detection_visual: Polygon2D = $DetectionZone/DetectionVisual
@onready var detection_shape: CollisionShape2D = $DetectionZone/CollisionShape2D

func _ready() -> void:
	health = max_health; mana = max_mana; stamina = max_stamina
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	detection_visual.color = Color(0.2, 0.4, 1.0, 0.05)
	InventoryManager.register_character("Player")

func _physics_process(delta: float) -> void:
	if is_stunned:
		stun_timer -= delta
		velocity = Vector2.ZERO
		if stun_timer <= 0: is_stunned = false
	else:
		handle_movement(delta)
	
	move_and_slide()
	record_history()
	update_targeting_logic()
	update_detection_radius()
	stats_changed.emit(health, mana, stamina)

func update_detection_radius():
	var target_radius = base_detection_radius
	if is_crouching: target_radius *= 0.5
	elif is_sprinting: target_radius *= 1.5
	
	if detection_shape.shape:
		detection_shape.shape.radius = target_radius
		
	# Draw the circle visual
	var points = PackedVector2Array()
	var sides = 32
	for i in range(sides):
		var angle = i * PI * 2 / sides
		points.append(Vector2(cos(angle), sin(angle)) * target_radius)
	detection_visual.polygon = points

func handle_movement(delta: float):
	is_crouching = Input.is_action_pressed("crouch")
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	var current_speed = walk_speed
	is_sprinting = false
	
	if is_crouching:
		current_speed = crouch_speed
		sprite.color = Color("#111155")
	else:
		sprite.color = Color("#3344ff")
		if Input.is_action_pressed("sprint") and stamina > 0 and input_dir != Vector2.ZERO:
			is_sprinting = true
			current_speed = sprint_speed
			stamina -= 25.0 * delta
		else:
			stamina = min(stamina + 15.0 * delta, max_stamina)
	
	velocity = input_dir * current_speed * slow_multiplier

func record_history():
	# Only record if we actually moved or changed state, to prevent NPC from stacking on us
	if velocity.length() > 5.0 or (not position_history.is_empty() and position_history.back()["crouch"] != is_crouching):
		var data = {
			"pos": global_position,
			"sprint": is_sprinting,
			"crouch": is_crouching
		}
		position_history.append(data)
		if position_history.size() > 120:
			position_history.remove_at(0)

func update_targeting_logic():
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies: e.is_highlighted = false
	can_cast = false
	
	if current_skill_mode == SkillMode.NONE: return
	var mouse_pos = get_global_mouse_position()
	
	if current_skill_mode == SkillMode.FIREBALL:
		for e in enemies:
			if e.global_position.distance_to(mouse_pos) < 80.0: # Larger detection for fireball
				e.is_highlighted = true
				can_cast = true
	elif current_skill_mode == SkillMode.ARROW:
		# Use group check + distance as a fallback if point query fails
		for e in enemies:
			if e.global_position.distance_to(mouse_pos) < 30.0:
				e.is_highlighted = true
				can_cast = true
				break

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		check_for_interactions()
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_skill_mode != SkillMode.NONE and can_cast:
				cast_active_skill(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			current_skill_mode = SkillMode.NONE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(0.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(-0.2)

func check_for_interactions():
	# Loot containers take priority so the player doesn't accidentally talk to an NPC
	# while trying to pick something up.
	var containers = get_tree().get_nodes_in_group("loot_container")
	for container in containers:
		if global_position.distance_to(container.global_position) < 60.0:
			if container.has_method("interact"):
				container.interact()
				return

	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if global_position.distance_to(npc.global_position) < 60.0:
			if npc.has_method("interact"):
				npc.interact()
				return

	var buildings = get_tree().get_nodes_in_group("building")
	for building in buildings:
		if "player_in_zone" in building and building.player_in_zone:
			if building.has_method("interact"):
				building.interact()
				return

func _adjust_zoom(delta: float) -> void:
	var new_zoom: float = clamp($Camera2D.zoom.x + delta, 0.5, 4.0)
	$Camera2D.zoom = Vector2(new_zoom, new_zoom)

func set_skill_mode(mode): current_skill_mode = mode as SkillMode

func cast_active_skill(target_pos: Vector2):
	if current_skill_mode == SkillMode.FIREBALL:
		if mana >= 15.0:
			mana -= 15.0
			var fb = FIREBALL_SCENE.instantiate()
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

func heal(amt):
	health = min(health + amt, max_health); mana = max_mana; stamina = max_stamina
	stats_changed.emit(health, mana, stamina)

func restore_health(amt: float):
	health = min(health + amt, max_health)
	stats_changed.emit(health, mana, stamina)

func restore_mana(amt: float):
	mana = min(mana + amt, max_mana)
	stats_changed.emit(health, mana, stamina)

func restore_stamina(amt: float):
	stamina = min(stamina + amt, max_stamina)
	stats_changed.emit(health, mana, stamina)

func apply_trap_damage(amt):
	health = max(0, health - amt)
	stats_changed.emit(health, mana, stamina)

func apply_slow(mult): slow_multiplier = mult
func clear_slow(): slow_multiplier = 1.0
func apply_stun(dur): 
	if not is_crouching:
		is_stunned = true
		stun_timer = dur
