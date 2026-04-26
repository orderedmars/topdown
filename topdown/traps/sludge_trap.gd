extends Area2D

@export var damage_per_second: float = 10.0
@export var slow_amount: float = 0.75 # 25% slow

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.apply_trap_damage(damage_per_second * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.apply_slow(slow_amount)
		print("Entered Sludge Trap!")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.clear_slow()
		print("Exited Sludge Trap!")
