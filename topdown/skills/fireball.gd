extends Area2D

var velocity = Vector2.ZERO
var damage = 40.0
var speed = 400.0
var target_pos = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Set mask to hit World(1) and Entities(2)
	collision_mask = 3 
	# Clear layer so nothing hits the fireball
	collision_layer = 0

func _physics_process(delta: float) -> void:
	global_position = global_position.move_toward(target_pos, speed * delta)
	if global_position == target_pos:
		explode()

func explode():
	var bodies = get_overlapping_bodies()
	# AoE chips everything that can take damage. Battle triggers with the first
	# enemy that survives the chip — others stay in the dungeon at reduced HP.
	var battle_target: Node = null
	for body in bodies:
		if not body.has_method("take_damage"):
			continue
		body.take_damage(damage)
		if battle_target == null and body.is_in_group("enemy") and is_instance_valid(body) and body.health > 0:
			battle_target = body
	if battle_target != null:
		BattleManager.start_battle(battle_target)
	queue_free()

func _on_body_entered(body):
	# Projectiles are Area2D, so they detect bodies. 
	# Collision mask 3 = World(1) + Entities(2).
	# This avoids the Detection Zones on Layer 4.
	if body is StaticBody2D or body.is_in_group("enemy"):
		explode()
