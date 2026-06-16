extends Area2D

var damage = 20.0
var speed = 600.0
var direction = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_mask = 3 # World and Entities
	collision_layer = 0

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.is_in_group("enemy") and is_instance_valid(body) and body.health > 0:
			BattleManager.start_battle(body)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
