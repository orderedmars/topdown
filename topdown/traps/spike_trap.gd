extends Area2D

@export var instant_damage: float = 20.0
@export var stun_duration: float = 2.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.apply_trap_damage(instant_damage)
		body.apply_stun(stun_duration)
		print("Stepped on Spike Trap!")
